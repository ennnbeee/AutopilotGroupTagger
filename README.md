# 🏷 AutopilotGroupTagger

AutoPilotGroupTagger is a PowerShell 7 based utility that allows for bulk update and management of Windows Autopilot Device Group Tags, for those who are either retrospectively updating Autopilot devices or otherwise.

## ⚠ Public Preview Notice

AutoPilotGroupTagger is currently in Public Preview, meaning that although the utility is functional, you may encounter issues or bugs with the script.

To help fix or contribute to the success of this script, feedback or contributions are crucial for improving the script.

- 📝 [Submit Feedback](https://github.com/ennnbeee/AutopilotGroupTagger/issues/new?labels=feedback)
- 🐛 [Report Bugs](https://github.com/ennnbeee/AutopilotGroupTagger/issues/new?labels=bug)
- 💡 [Request Features](https://github.com/ennnbeee/AutopilotGroupTagger/issues/new?labels=enhancement)

 Thank you for your support.

## 🗒 Prerequisites

- Tested on PowerShell 7.0 or higher
- Microsoft.Graph.Authentication Module should be installed, the script will detect and install if required.
- Entra ID App Registration with appropriate Graph Scopes or using Interactive Sign-In with a privileged account
- Windows Operating System

## ⏯ Usage

Download the script: AutopilotGroupTagger.ps1

Running the script without any parameters for interactive authentication:

```powershell
.\AutopilotGroupTagger.ps1
```

OR

Run the script with the your Entra ID Tenant ID passed to the `tenantID` parameter e.g.:

```powershell
.\AutopilotGroupTagger.ps1 -tenantID '437e8ffb-3030-469a-99da-e5b527908099'
```

OR

Create an Entra ID App Registration with the following Graph API Application permissions:

- `DeviceManagementServiceConfig.ReadWrite.All`
- `Device.Read.All`
- `DeviceManagementManagedDevices.Read.All`

Create an App Secret for the App Registration to be used when running the script.

Then run the script with the corresponding Entra ID Tenant ID, AppId and AppSecret passed to the parameters e.g.:

```powershell
.\AutopilotGroupTagger.ps1 -tenantID '437e8ffb-3030-469a-99da-e5b527908099' -appId '799ebcfa-ca81-4e63-baaf-a35123164d78' -appSecret 'g708Q~uot4xo9dU_1TjGQIuUr0UyBHNZmY2mdcy6'
```

### 🔐 Authentication

![AutoPilotGroupTagger](img/AutopilotGroupTagger.gif)

Select one of the options to start applying Group Tags to your Autopilot Devices:

- 💻🖥 Update **All Windows Autopilot Devices** with a new Group Tag
- 💻❌ Update Windows Autopilot Devices with **an empty Group Tag** with a new Group Tag
- 💻🏷 Update Windows Autopilot Devices with **specific existing Group Tags** with a new Group Tag
- 💻🏢 Update **specific manufacturers** of Windows Autopilot Devices with a new Group Tag
- 💻🏠 Update **specific models** of Windows Autopilot Devices with a new Group Tag
- 💻❔ Update **specific interactively selected** Windows Autopilot Devices with a new Group Tag
- 💻📔 Export Windows Autopilot Device data, and **selectively update** multiple devices with new Group Tags