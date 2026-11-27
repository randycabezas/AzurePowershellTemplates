# Azure PowerShell Administration & Bicep Deployment Scripts

A collection of reusable PowerShell scripts built to streamline Azure administration, enforce consistent authentication and tagging guardrails, and simplify interactive Bicep template deployments.

---

## Scripts Included

| Script                                                                            | Purpose                                                                                                                                                                                                                            |
| :-------------------------------------------------------------------------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **`Templates\AzurePowershellTemplate.ps1`**<br>[[AzurePowershellTemplate-README]] | Reusable base boilerplate for Azure automation scripts. Handles module checks, interactive login, subscription context switching, and standardized governance variables.                                                           |
| **`Scripts\AzLoadBicep.ps1`**<br>[[AzLoadBicep-README]]                           | Interactive Bicep deployment utility built on top of the base template. Lets you visually select a target Resource Group and browse for a `.bicep` template, validates it against Azure, and deploys with confirmation guardrails. |


---

## Prerequisites

* **PowerShell:** PowerShell 7.2+ recommended (Windows PowerShell 5.1 is also supported).
* **Azure PowerShell Module (`Az`):**
  ```powershell
  Install-Module -Name Az -Repository PSGallery -Force
  ```
* **Azure Bicep CLI:** Required for compiling and validating `.bicep` files during deployment.
  ```powershell
  # Install via winget (Windows)
  winget install Microsoft.Bicep

  # Or install via Azure CLI
  az bicep install
  ```
* **OS / GUI Support:** `Out-GridView` and `System.Windows.Forms.OpenFileDialog` provide native Windows GUI pickers. In headless terminals (SSH, Linux/macOS, or Azure Cloud Shell), `loadbicep.ps1` automatically falls back to console prompts.

---
