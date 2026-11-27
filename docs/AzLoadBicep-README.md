# Interactive Bicep Loader (`AzLoadBicep.ps1`)

`AzLoadBicep.ps1` extends the base template to provide a guided, error-checked workflow for deploying Bicep templates into Azure Resource Groups.

### Workflow

1. **Context Initialization:** Verifies your Azure login and displays the active user, subscription, tenant, and default region banner.
   ![Image 1](../assets/images/image%281%29.png)
2. **Resource Group Selection:** Fetches all Resource Groups in the active subscription and opens a searchable `Out-GridView` window (bypassed if `-ResourceGroupName` is provided at runtime).
   ![Image 2](../assets/images/image%282%29.png)
3. **Bicep File Selection:** Opens a native Windows File Browser filtered to `*.bicep` files (bypassed if `-TemplateFile` is provided at runtime).   
   ![Image 3](../assets/images/image%283%29.png)
4. **Pre-Flight Validation:** Runs `Test-AzResourceGroupDeployment` to catch Bicep syntax errors, invalid API versions, or missing parameters before modifying Azure resources.
   ![Image 5](../assets/images/image%285%29.png)
5. **Confirmation Gate:** Displays a deployment summary and prompts `(Y/N)` before executing `New-AzResourceGroupDeployment` (bypassed when `-Force` is passed).
   ![Image 4](../assets/images/image%284%29.png)
6. **Deployment & Outputs:** Names the deployment `<TemplateBaseName>-<Timestamp>` for traceability in the Azure Portal and prints any Bicep `output` values upon completion.

### Additional Parameters

| Parameter       | Type     | Description                                                                              |
|:--------------- |:-------- |:---------------------------------------------------------------------------------------- |
| `-TemplateFile` | `String` | Path to a `.bicep` (or ARM `.json`) file. Skips the file browser dialog when specified.  |
| `-Force`        | `Switch` | Bypasses the interactive `(Y/N)` confirmation prompt prior to deployment.                |
| `-WhatIf`       | `Switch` | Runs pre-flight validation and simulates the deployment without making changes in Azure. |

### Usage Examples

**Fully interactive mode (GUI pickers + confirmation prompt):**

```powershell
.\AzLoadBicep.ps1
```

**Target a specific subscription interactively:**

```powershell
.\AzLoadBicep.ps1 -SubscriptionId "00000000-0000-0000-0000-000000000000" -Verbose
```

**Dry-run validation (`-WhatIf`) with pre-selected inputs:**

```powershell
.\AzLoadBicep.ps1 -ResourceGroupName "rg-az104-lab" -TemplateFile ".\main.bicep" -Force -WhatIf
```

**Unattended / automated deployment:**

```powershell
.\AzLoadBicep.ps1 -ResourceGroupName "rg-az104-lab" -TemplateFile ".\main.bicep" -Force
```
