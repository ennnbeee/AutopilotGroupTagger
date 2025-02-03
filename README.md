# 🏷 AutopilotGroupTagger

AutoPilotGroupTagger is a PowerShell based utility that allows for bulk update and management of Windows Autopilot Device Group Tags, for those who are either retrospectively updating Autopilot devices or otherwise.

## ⚠ Public Preview Notice

AutopilotGroupTagger is currently in Public Preview, meaning that although the it is functional, you may encounter issues or bugs with the script.

## 🗒 Prerequisites

- Tested on PowerShell 5 and PowerShell 7
- Microsoft.Graph.Authentication Module should be installed, the script will detect and install if required.
- Entra ID App Registration with appropriate Graph Scopes or using Interactive Sign-In with a privileged account
- Windows Operating System

## 🔄 Updates

- v0.4: Now supports PowerShell 5
- v0.3: Improved logic around Autopilot device selection options
- v0.2: Included functionality to update group tags based on Purchase order
- v0.1: Initial release

## ⏯ Usage

Download the script: AutopilotGroupTagger.ps1

Running the script without any parameters for interactive authentication:

```powershell
.\AutopilotGroupTagger.ps1
```

OR

Run the script with the your Entra ID Tenant ID passed to the `tenantID` parameter:

```powershell
.\AutopilotGroupTagger.ps1 -tenantID '437e8ffb-3030-469a-99da-e5b527908099'
```

OR

Create an Entra ID App Registration with the following Graph API Application permissions:

- `DeviceManagementServiceConfig.ReadWrite.All`
- `Device.Read.All`
- `DeviceManagementManagedDevices.Read.All`

Create an App Secret for the App Registration to be used when running the script.

Then run the script with the corresponding Entra ID Tenant ID, AppId and AppSecret passed to the parameters:

```powershell
.\AutopilotGroupTagger.ps1 -tenantID '437e8ffb-3030-469a-99da-e5b527908099' -appId '799ebcfa-ca81-4e63-baaf-a35123164d78' -appSecret 'g708Q~uot4xo9dU_1TjGQIuUr0UyBHNZmY2mdcy6'
```

### 🔐 Authentication

Authentication using the Tenant ID looks like the below:

![AutoPilotGroupTagger](img/agt-demo-auth-tenant.gif)

### 🌟 Features

Once authenticated select one of the options to start applying Group Tags to your Autopilot Devices:

- 💻🖥 Update **All Windows Autopilot Devices** with a new Group Tag
- 💻❌ Update Windows Autopilot Devices with **an empty Group Tag** with a new Group Tag
- 💻🏷 Update Windows Autopilot Devices with **specific existing Group Tags** with a new Group Tag
- 💻🏢 Update **specific manufacturers** of Windows Autopilot Devices with a new Group Tag
- 💻🏠 Update **specific models** of Windows Autopilot Devices with a new Group Tag
- 💻💰 Update Windows Autopilot Devices with **specific Purchase Orders** with a new Group Tag
- 💻❔ Update **specific interactively selected** Windows Autopilot Devices with a new Group Tag
- 💻📔 Export Windows Autopilot Device data, and **selectively update** multiple devices with new Group Tags
- 💻😅 Exit the script before you cause yourself some problems

## 🎬 Demos

### 1️⃣ Update All Windows Autopilot Devices

![AutoPilotGroupTagger](img/agt-demo-alldevices.gif)

### 2️⃣ Update Windows Autopilot Devices with an empty Group Tag

![AutoPilotGroupTagger](img/agt-demo-allempty.gif)

### 3️⃣ Update Windows Autopilot Devices with specific existing Group Tags

![AutoPilotGroupTagger](img/agt-demo-tags.gif)

### 4️⃣ Update specific manufacturers of Windows Autopilot Devices

![AutoPilotGroupTagger](img/agt-demo-makes.gif)

### 5️⃣ Update specific models of Windows Autopilot Devices

![AutoPilotGroupTagger](img/agt-demo-models.gif)

### 6️⃣ Update Windows Autopilot Devices with specific Purchase Orders

Demo Coming Soon

### 7️⃣ Update specific interactively selected Windows Autopilot Devices

![AutoPilotGroupTagger](img/agt-demo-specific.gif)

### 8️⃣ Export Windows Autopilot Device data, and selectively update multiple devices

![AutoPilotGroupTagger](img/agt-demo-report.gif)

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
