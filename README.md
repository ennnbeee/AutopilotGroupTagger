# 🏷 AutopilotGroupTagger

AutoPilotGroupTagger is a PowerShell based utility that allows for bulk update and management of Windows Autopilot Device Group Tags, or unblocking of Autopilot devices, for those who are either retrospectively updating Autopilot devices or otherwise.

## MEM Official Community Tool

This script has been recognised as part of the [MEM Official Community Tools](https://www.memcommunity.com/official-community-tool-oct) and was carefully reviewed by a panel of industry experts.

This solution was evaluated based on technical value, originality, usefulness, and impact on the Endpoint Management ecosystem.

## ⚠ Public Preview Notice

AutopilotGroupTagger is currently in Public Preview, meaning that although the it is functional, you may encounter issues or bugs with the script.

> [!TIP]
> If you do encounter bugs, want to contribute, submit feedback or suggestions, please create an issue.

## ☑ Options

- 🛍 Option to create Dynamic Groups based on new Group Tags
- ⁉ Option to run in whatIf mode to simulate Group Tag or Dynamic Group changes

## 🌟 Features

Once authenticated select one of the options to start updating Group Tags to your Autopilot devices:

- 🖥 Update all Windows Autopilot devices with a new Group Tag
- ❌ Update Windows Autopilot devices with an empty Group Tag with a new Group Tag
- 🏷 Update Windows Autopilot devices with specific existing Group Tags with a new Group Tag
- 🏢 Update specific manufacturers of Windows Autopilot devices with a new Group Tag
- 🏠 Update specific models of Windows Autopilot devices with a new Group Tag
- 💰 Update Windows Autopilot devices with specific Purchase Orders with a new Group Tag
- ❔ Update specific interactively selected Windows Autopilot devices with a new Group Tag
- 📔 Export Windows Autopilot Device data, and selectively update multiple devices with new Group Tags
- 🛑 Remove existing Group Tags across all scenarios

Also options to [unblock](https://learn.microsoft.com/en-us/autopilot/whats-new#how-to-unblock-devices) Autopilot devices:

- 🖥 Unblock all Windows Autopilot devices
- ❌ Unblock all blocked Windows Autopilot devices
- 🏢 Unblock specific manufacturers of Windows Autopilot devices
- 🏠 Unblock specific models of Windows Autopilot devices

> [!NOTE]
> Before the Group Tags are assigned or removed, or the groups created, you are prompted whether you want to continue.

## 🗒 Prerequisites

> [!IMPORTANT]
>
> - Supports PowerShell 7 on Windows and macOS
> - `Microsoft.Graph.Authentication` module should be installed, the script will detect and install if required.
> - `Microsoft.PowerShell.ConsoleGuiTools` module should be installed, the script will detect and install if required.
> - Entra ID App Registration with appropriate Graph Scopes or using Interactive Sign-In with a privileged account

## 🔄 Updates

- **v0.7.0**
  - Updated to allow for re-running of the script
  - Bug fixes and UI improvements
- v0.6.0
  - New functionality to allow for unblocking of Autopilot devices
- v0.5.0
  - Allows for removal of Group Tags on Autopilot devices
  - Option to create Dynamic Entra ID groups based on the Group Tags
  - Support for PowerShell 7 on macOS and Windows replacing `Out-GridView` with `Out-ConsoleGridView` as part of the `Microsoft.PowerShell.ConsoleGuiTools` module
  - Allow for reselection of Group Tags, device makes and models, and purchase orders
- v0.4.0
  - Now supports PowerShell 5
- v0.3.0
  - Improved logic around Autopilot device selection options
- v0.2.0
  - Included functionality to update group tags based on Purchase order
- v0.1.0
  - Initial release

## ⏯ Usage

Install the script from the [PowerShell Gallery](https://www.powershellgallery.com/packages/AutopilotGroupTagger)

```PowerShell
Install-Script -Name AutopilotGroupTagger
```

Running the script without any parameters for interactive authentication:

```powershell
.\AutopilotGroupTagger.ps1
```

OR

Run the script with the your Entra ID Tenant ID passed to the `tenantID` parameter:

```powershell
.\AutopilotGroupTagger.ps1 -tenantID '437e8ffb-3030-469a-99da-e5b527908099'
```

![AutoPilotGroupTagger Authentication using tenantID](img/agt-demo-auth-tenant.gif)

OR

Create an Entra ID App Registration with the following Graph API Application permissions:

- `Group.ReadWrite.All`
- `DeviceManagementServiceConfig.ReadWrite.All`
- `Device.Read.All`
- `DeviceManagementManagedDevices.Read.All`

Create an App Secret for the App Registration to be used when running the script.

Then run the script with the corresponding Entra ID Tenant ID, AppId and AppSecret passed to the parameters:

```powershell
.\AutopilotGroupTagger.ps1 -tenantID '437e8ffb-3030-469a-99da-e5b527908099' -appId '799ebcfa-ca81-4e63-baaf-a35123164d78' -appSecret 'g708Q~uot4xo9dU_1TjGQIuUr0UyBHNZmY2mdcy6'
```

### 🛍 Group Creation

If you want the script to create dynamic groups based on the new Group Tags provided, include the switch parameter `createGroups`:

```PowerShell
.\AutopilotGroupTagger.ps1 -createGroups -groupPrefix 'AGT-Autopilot-'
```

This will allow for groups to be created with a prefix of **AGT-Autopilot-** followed by the Group Tag you specify, only if a group with the same name does not already exist.

### ⁉ WhatIf Mode

If you want the script to just simulate the update of Group Tags use the `whatIf` parameter:

```PowerShell
.\AutopilotGroupTagger.ps1 -whatIf
```

> [!NOTE]
> This `whatIf` parameter will allow the simulation of the update of Group Tags, all other prompts will remain the same.

## 🎬 Demos

### 🛍 Create Groups

![AutoPilotGroupTagger](img/agt-demo-ps7-groups.gif)

### 1️⃣ Update All Windows Autopilot devices

![AutoPilotGroupTagger](img/agt-demo-alldevices.gif)

### 2️⃣ Update Windows Autopilot devices with an empty Group Tag

![AutoPilotGroupTagger](img/agt-demo-allempty.gif)

### 3️⃣ Update Windows Autopilot devices with specific existing Group Tags

![AutoPilotGroupTagger](img/agt-demo-tags.gif)

### 4️⃣ Update specific manufacturers of Windows Autopilot devices

![AutoPilotGroupTagger](img/agt-demo-makes.gif)

### 5️⃣ Update specific models of Windows Autopilot devices

![AutoPilotGroupTagger](img/agt-demo-models.gif)

### 6️⃣ Update Windows Autopilot devices with specific Purchase Orders

Demo coming at some point, maybe.

### 7️⃣ Update specific interactively selected Windows Autopilot devices

![AutoPilotGroupTagger](img/agt-demo-specific.gif)

### 8️⃣ Export Windows Autopilot Device data, and selectively update multiple devices

![AutoPilotGroupTagger](img/agt-demo-report.gif)

### A Unblock All Windows Autopilot devices

Demo coming at some point, maybe.

### B Unblock blocked Windows Autopilot devices

Demo coming at some point, maybe.

### C Unblock specific manufacturers of Windows Autopilot devices

Demo coming at some point, maybe.

### D Unblock specific models of Windows Autopilot devices

Demo coming at some point, maybe.

## 🚑 Support

If you encounter any issues or have questions:

1. Check the [Issues](https://github.com/ennnbeee/AutopilotGroupTagger/issues) page
2. Open a new issue if needed

- 📝 [Submit Feedback](https://github.com/ennnbeee/AutopilotGroupTagger/issues/new?labels=feedback)
- 🐛 [Report Bugs](https://github.com/ennnbeee/AutopilotGroupTagger/issues/new?labels=bug)
- 💡 [Request Features](https://github.com/ennnbeee/AutopilotGroupTagger/issues/new?labels=enhancement)

Thank you for your support.

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

Created by [Nick Benton](https://github.com/ennnbeee) of [odds+endpoints](https://www.oddsandendpoints.co.uk/)
