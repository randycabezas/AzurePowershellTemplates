# Base Script Template (`AzurePowershellTemplate.ps1`)

Use this file as the starting point for any new Azure administration script. It separates environment setup from operational logic using three structured regions:

1. **Module & Connection Verification (`#region 1`):**
   * Confirms `Az.Accounts` is installed.
   * Checks for an active Azure session via `Get-AzContext`. If none exists, prompts the user and runs `Connect-AzAccount`, normalizing the returned context object.
   * Switches active subscription context automatically if `-SubscriptionId` is supplied.
2. **Environment & Context Variables (`#region 2`):**
   * Populates standard variables ready for use anywhere in the script:
     * `$CurrentTenantId`, `$CurrentSubscriptionId`, `$CurrentSubName`, `$CurrentUser`, `$CurrentEnvironment`
     * `$Timestamp` (`yyyyMMdd-HHmm` format for unique resource/deployment naming)
     * `$DefaultTags` (pre-populated hashtable with `Environment`, `ManagedBy`, `CreatedBy`, and `LastUpdated`)
   * Validates `-ResourceGroupName` (if passed) and inherits its Azure region into `$Location` unless overridden.
3. **Main Script Execution (`#region 3`):**
   * Wraps operational workloads inside a `try / catch / finally` block with `$ErrorActionPreference = 'Stop'` and `SupportsShouldProcess` (`-WhatIf` / `-Confirm`) support.

### Common Parameters

| Parameter            | Type            | Default          | Description                                                                   |
| :------------------- | :-------------- | :--------------- | :---------------------------------------------------------------------------- |
| `-SubscriptionId`    | `String (GUID)` | Active context   | Target Azure Subscription ID.                                                 |
| `-TenantId`          | `String (GUID)` | Active context   | Target Microsoft Entra ID (Tenant) ID.                                        |
| `-ResourceGroupName` | `String`        | `$null`          | Target Resource Group name.                                                   |
| `-Location`          | `String`        | `northcentralus` | Default Azure region. Inherited from the Resource Group if it already exists. |
| `-EnvironmentTag`    | `String`        | `Dev`            | Value applied to the `Environment` key in `$DefaultTags`.                     |
| `-TemplateFile`      | `String`        | `$null`          | Path to a file. Skips the file browser dialog when specified.                 |

---
