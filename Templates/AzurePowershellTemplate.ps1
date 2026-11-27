<#
=============================================================================
Azure Powershell Template - General Template win Variables assigned 
Dynamically.
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
.EXAMPLE
    .\AzurePowershellTemplate.ps1 -SubscriptionId "00000000-0000-0000-0000-000000000000" -Verbose
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
    [string]$TemplateFile
)

# Stop execution on unhandled errors to prevent partial/broken runs
$ErrorActionPreference = 'Stop'

#region 1. Module & Connection Verification
Write-Verbose "Checking for Powershell Module: Az.Accounts ..."
if (-not (Get-Module -ListAvailable -Name Az.Accounts)) {
    throw "The 'Az.Accounts' module is not installed. Run 'Install-Module -Name Az -Repository PSGallery -Force' first."
}

#
# Let's See if we are connected already by looking at context
#
$azContext = Get-AzContext

#
# If not connected then we will drop into this sequence.
#
if (-not $azContext -or -not $azContext.Account) {
    Write-Warning "No active Azure session found."
    $connectChoice = Read-Host "Would you like to connect to Azure now? (Y/N)"
    # Confirm they want to connect first
    if ($connectChoice -match '^[Yy]') {
        try {
            # Load passed parameters if exist.
            $connectParams = @{}
            if ($TenantId) { $connectParams['TenantId'] = $TenantId }
            if ($SubscriptionId) { $connectParams['SubscriptionId'] = $SubscriptionId }
            
            Write-Host "Launching Azure authentication prompt..." -ForegroundColor Cyan
            
            # Connect to Azure using variables provided or none if not.
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
#endregion 1.


#region 2. Populate Common Environment & Context Variables
$CurrentTenantId       = $azContext.Tenant.Id
$CurrentSubscriptionId = $azContext.Subscription.Id
$CurrentSubName        = $azContext.Subscription.Name
$CurrentUser           = $azContext.Account.Id
$CurrentEnvironment    = $azContext.Environment.Name # e.g., AzureCloud, AzureUSGovernment

#
# Standardized Metadata & Naming Helpers
# For use in your main script below.
#
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
#endregion 2.

#region 3. Main Script Execution
try {
    Write-Verbose "Starting main workload..."

    # -------------------------------------------------------------------------
    # [INSERT SCRIPT-SPECIFIC LOGIC HERE]
    # Available pre-populated variables:
    #   $azContext, $CurrentTenantId, $CurrentSubscriptionId, $CurrentSubName,
    #   $CurrentUser, $Location, $ResourceGroupName, $TargetResourceGroup,
    #   $Timestamp, $DefaultTags
    # -------------------------------------------------------------------------

}
catch {
    Write-Error "An error occurred during script execution: $_"
    exit 1
}
finally {
    Write-Verbose "Script execution completed."
}
#endregion 3.

#region final.
#
# Final region. Add clean up steps if needed.




#endregion final.