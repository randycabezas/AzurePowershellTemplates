<#
=============================================================================
Azure Bicep File loader - Interactive Loader

Interactive Bicep deployment utility built on top of the base template. 
Lets you visually select a target Resource Group and browse for a .bicep 
template, validates it against Azure, and deploys with confirmation 
guardrails. 

-----------------------------------------------------------------------------
Author..........: Randall Cabezas
					(https://www.linkedin.com/in/randallcabezas)
					(https://github.com/randycabezas)
				  AI: Assisted in Code Clean Up
-----------------------------------------------------------------------------
THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND,
EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
=============================================================================
.SYNOPSIS
    Base template for Azure administration scripts.
.DESCRIPTION
    Verifies the Az PowerShell module, checks for an active Azure session (connecting 
    interactively if needed), sets the target subscription, and populates standard 
    context variables for downstream automation.
.PARAMETER SubscriptionId
    Optional. The specific Azure Subscription ID to target. Defaults to the active context.
.PARAMETER TenantId
    Optional. The Entra ID (Tenant) ID to authenticate against.
.PARAMETER ResourceGroupName
    Optional. Default Resource Group name for the script's operations.
.PARAMETER Location
    Optional. Default Azure region (e.g., eastus, westus2). Defaults to 'northcentralus' for this particular account.
.PARAMETER EnvironmentTag
    Optional. Defaults to 'Dev' so that things are not marked as Prod all the time.
.PARAMETER TemplateFile
    Optional. In case you need to load a file.
.PARAMETER Force
    Optional. Will skip confirmation when deploying.
.EXAMPLE
    .\loadbicep.ps1 -SubscriptionId "00000000-0000-0000-0000-000000000000" -Verbose
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [Parameter(Mandatory = $false)]
    [ValidatePattern('^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$')]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$')]
    [string]$TenantId,

    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [string]$Location = "northcentralus",

    [Parameter(Mandatory = $false)]
    [string]$EnvironmentTag = "Dev",

    [Parameter(Mandatory = $false)]
    [string]$TemplateFile,

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

# Stop execution on unhandled errors to prevent partial/broken runs
$ErrorActionPreference = 'Stop'

#region 1. Module & Connection Verification
Write-Verbose "Checking for Az.Accounts module..."
if (-not (Get-Module -ListAvailable -Name Az.Accounts)) {
    throw "The 'Az.Accounts' module is not installed. Run 'Install-Module -Name Az -Repository PSGallery -Force' first."
}

$azContext = Get-AzContext

if (-not $azContext -or -not $azContext.Account) {
    Write-Warning "No active Azure session found."
    $connectChoice = Read-Host "Would you like to connect to Azure now? (Y/N)"
    
    if ($connectChoice -match '^[Yy]') {
        try {
            $connectParams = @{}
            if ($TenantId) { $connectParams['TenantId'] = $TenantId }
            if ($SubscriptionId) { $connectParams['SubscriptionId'] = $SubscriptionId }
            
            Write-Host "Launching Azure authentication prompt..." -ForegroundColor Cyan
            
            # Discard the AzureRmProfile output, then explicitly pull the flat AzureContext
            Connect-AzAccount @connectParams | Out-Null
            $azContext = Get-AzContext
        }
        catch {
            throw "Failed to authenticate to Azure: $_"
        }
    }
    else {
        Write-Host "Execution aborted by user." -ForegroundColor Yellow
        exit 0
    }
}

# Verify a valid context and subscription were loaded after authentication
if (-not $azContext -or -not $azContext.Subscription) {
    throw "Authentication succeeded, but no active Azure subscription was found in the context. Verify your account has access to at least one subscription."
}

# Switch subscription context if a specific SubscriptionId was passed and differs from current
if ($SubscriptionId -and ($azContext.Subscription.Id -ne $SubscriptionId)) {
    Write-Verbose "Switching context to Subscription ID: $SubscriptionId"
    try {
        $azContext = Set-AzContext -SubscriptionId $SubscriptionId
    }
    catch {
        throw "Unable to set context to Subscription '$SubscriptionId'. Verify permissions. Details: $_"
    }
}
#endregion


#region 2. Populate Common Environment & Context Variables
$CurrentTenantId       = $azContext.Tenant.Id
$CurrentSubscriptionId = $azContext.Subscription.Id
$CurrentSubName        = $azContext.Subscription.Name
$CurrentUser           = $azContext.Account.Id
$CurrentEnvironment    = $azContext.Environment.Name # e.g., AzureCloud, AzureUSGovernment

# Standardized Metadata & Naming Helpers
$Timestamp             = (Get-Date).ToString("yyyyMMdd-HHmm")
$DefaultTags           = @{
    Environment = $EnvironmentTag
    ManagedBy   = "PowerShell"
    CreatedBy   = $CurrentUser
    LastUpdated = (Get-Date).ToString("yyyy-MM-dd")
}

# Validate Resource Group if provided in parameters
$TargetResourceGroup = $null
if ($ResourceGroupName) {
    $TargetResourceGroup = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
    if (-not $TargetResourceGroup) {
        Write-Warning "Resource Group '$ResourceGroupName' does not exist in subscription '$CurrentSubName'."
    }
    else {
        # Inherit location from the RG if not explicitly overridden
        if (-not $PSBoundParameters.ContainsKey('Location')) {
            $Location = $TargetResourceGroup.Location
        }
    }
}

# Display active execution banner

Write-Host "==========================================================" -ForegroundColor DarkGray
Write-Host " Azure Context Initialized" -ForegroundColor Green
Write-Host " User         : $CurrentUser"
Write-Host " Subscription : $CurrentSubName ($CurrentSubscriptionId)"
Write-Host " Tenant       : $CurrentTenantId"
Write-Host " Location     : $Location"
if ($ResourceGroupName) { Write-Host " Target RG    : $ResourceGroupName" }
Write-Host "==========================================================" -ForegroundColor DarkGray
#endregion

#region 3. Main Script Execution
try {
    Write-Verbose "Fetching Resource Groups from subscription '$CurrentSubName'..."

    $resourceGroups = Get-AzResourceGroup | Select-Object `
        @{Name = 'Name'; Expression = { $_.ResourceGroupName } },
        Location,
        ProvisioningState,
        @{Name = 'Tags'; Expression = { 
            if ($_.Tags.Count -gt 0) { 
                ($_.Tags.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join '; ' 
            } else { 
                'None' 
            }
        }} | Sort-Object Name

    if (-not $resourceGroups) {
        Write-Warning "No Resource Groups found in subscription '$CurrentSubName'."
        exit 0
    }

    # --- Step A: Select Resource Group ---
    if ($ResourceGroupName -and $TargetResourceGroup) {
        $selectedRG = $resourceGroups | Where-Object { $_.Name -eq $ResourceGroupName }
    }
    else {
        Write-Host "`nOpening interactive Resource Group selector..." -ForegroundColor Cyan

        if (Get-Command Out-GridView -ErrorAction SilentlyContinue) {
            $selectedRG = $resourceGroups | Out-GridView `
                -Title "Select a Resource Group ($CurrentSubName)" `
                -OutputMode Single
        }
        else {
            Write-Warning "GUI GridView unavailable in this terminal. Falling back to console menu."
            for ($i = 0; $i -lt $resourceGroups.Count; $i++) {
                Write-Host ("  [{0}] {1} ({2})" -f ($i + 1), $resourceGroups[$i].Name, $resourceGroups[$i].Location)
            }
            $choice = Read-Host "Enter selection number (1-$($resourceGroups.Count))"
            if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $resourceGroups.Count) {
                $selectedRG = $resourceGroups[[int]$choice - 1]
            }
        }
    }

    if (-not $selectedRG) {
        Write-Host "No Resource Group selected. Operation cancelled." -ForegroundColor Yellow
        exit 0
    }

    $ResourceGroupName   = $selectedRG.Name
    $TargetResourceGroup = Get-AzResourceGroup -Name $ResourceGroupName
    if (-not $PSBoundParameters.ContainsKey('Location')) {
        $Location = $TargetResourceGroup.Location
    }

    Write-Host "`nSelected Resource Group: $ResourceGroupName ($Location)" -ForegroundColor Green

    # --- Step B: Select Bicep File via File Browser ---
    if (-not $TemplateFile) {
        Write-Host "Opening file browser to select Bicep template..." -ForegroundColor Cyan

        if ($IsWindows -or $PSVersionTable.PSVersion.Major -lt 6) {
            Add-Type -AssemblyName System.Windows.Forms

            $fileDialog = New-Object System.Windows.Forms.OpenFileDialog
            $fileDialog.Title            = "Select Bicep Template for '$ResourceGroupName'"
            $fileDialog.InitialDirectory = (Get-Location).Path
            $fileDialog.Filter           = "Bicep Templates (*.bicep)|*.bicep|ARM JSON Templates (*.json)|*.json|All Files (*.*)|*.*"
            $fileDialog.FilterIndex      = 1
            $fileDialog.Multiselect      = $false

            # Topmost dummy form forces the dialog to appear in front of VS Code / Windows Terminal
            $topForm = New-Object System.Windows.Forms.Form -Property @{ TopMost = $true }
            $dialogResult = $fileDialog.ShowDialog($topForm)
            $topForm.Dispose()

            if ($dialogResult -eq [System.Windows.Forms.DialogResult]::OK) {
                $TemplateFile = $fileDialog.FileName
            }
            else {
                Write-Host "File selection cancelled by user." -ForegroundColor Yellow
                exit 0
            }
        }
        else {
            # Console fallback for Linux / macOS / Cloud Shell
            $TemplateFile = Read-Host "Enter full path to the .bicep file"
        }
    }

    if (-not (Test-Path -Path $TemplateFile -PathType Leaf)) {
        throw "Bicep file not found at path: '$TemplateFile'"
    }

    # --- Step C: Validate & Deploy Bicep Template ---
    $bicepFileItem  = Get-Item -Path $TemplateFile
    $deploymentName = "$($bicepFileItem.BaseName)-$Timestamp"

    Write-Host "`nDeployment Summary:" -ForegroundColor Cyan
    Write-Host "  Subscription   : $CurrentSubName ($CurrentSubscriptionId)"
    Write-Host "  Resource Group : $ResourceGroupName ($Location)"
    Write-Host "  Bicep File     : $($bicepFileItem.FullName)"
    Write-Host "  Deployment Name: $deploymentName"

    # Run pre-flight validation before deploying
    Write-Host "`nValidating Bicep template against Azure..." -ForegroundColor Cyan
    $validationErrors = Test-AzResourceGroupDeployment `
        -ResourceGroupName $ResourceGroupName `
        -TemplateFile $bicepFileItem.FullName

    if ($validationErrors) {
        $errorDetails = $validationErrors | Out-String
        throw "Bicep template validation failed:`n$errorDetails"
    }
    Write-Host "Validation passed." -ForegroundColor Green

    # --- NEW: Confirmation Step (Bypassed if -Force is passed) ---
    if (-not $Force) {
        Write-Host "`nReady to deploy '$($bicepFileItem.Name)' into '$ResourceGroupName' ($CurrentSubName)." -ForegroundColor Yellow
        $confirmDeploy = Read-Host "Do you want to proceed with this deployment? (Y/N)"

        if ($confirmDeploy -notmatch '^[Yy]') {
            Write-Host "Deployment cancelled by user." -ForegroundColor Yellow
            exit 0
        }
    }
    else {
        Write-Verbose "-Force switch specified. Bypassing interactive deployment confirmation."
    }

    # Supports -WhatIf and prompts confirmation before modifying Azure resources
    if ($PSCmdlet.ShouldProcess("Resource Group '$ResourceGroupName'", "Deploy Bicep template '$($bicepFileItem.Name)'")) {
        Write-Host "Deploying Bicep template (this may take a few minutes)..." -ForegroundColor Cyan

        $deployment = New-AzResourceGroupDeployment `
            -Name $deploymentName `
            -ResourceGroupName $ResourceGroupName `
            -TemplateFile $bicepFileItem.FullName `
            -Verbose

        Write-Host "`nDeployment Succeeded!" -ForegroundColor Green
        $deployment | Select-Object DeploymentName, ProvisioningState, Timestamp | Format-Table -AutoSize

        if ($deployment.Outputs.Count -gt 0) {
            Write-Host "Deployment Outputs:" -ForegroundColor Cyan
            $deployment.Outputs.GetEnumerator() | ForEach-Object {
                Write-Host "  $($_.Key) : $($_.Value.Value)"
            }
        }
    }
}
catch {
    Write-Error "An error occurred during script execution: $_"
    exit 1
}
finally {
    Write-Verbose "Script execution completed."
}
#endregion

#region final.
#
# Final region. Add clean up steps if needed.




#endregion final.