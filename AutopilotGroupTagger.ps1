<#
.SYNOPSIS
Autopilot GroupTagger - Update Autopilot Device Group Tags in bulk.

.DESCRIPTION
The Autopilot GroupTagger script is designed to allow for bulk updating of Autopilot device group tags in Microsoft Intune.
The script will connect to the Microsoft Graph API and retrieve all Autopilot devices, then allow for bulk updating of group tags based on various criteria.

.NOTES
File Name      : AutopilotGroupTagger.ps1
Author         : Nick Benton
Prerequisite   : PowerShell 7, Microsoft Graph PowerShell SDK
Version        : 0.2 Preview
Date           : 2025-01-31
Updates:
    - 2025-02-03: 0.4 Configured to run on PowerShell 5
    - 2025-02-02: 0.3 Updated logic around Autopilot device selection
    - 2025-01-31: 0.2 Included functionality to update group tags based on Purchase order
    - 2025-01-31: 0.1 Initial release

.LINK
https://github.com/ennnbeee/AutopilotGroupTagger

.PARAMETER tenantId
Provide the Id of the Entra ID tenant to connect to.

.PARAMETER appId
Provide the Id of the Entra App registration to be used for authentication.

.PARAMETER appSecret
Provide the App secret to allow for authentication to graph

.EXAMPLE
Interactive Authentication
PS> .\AutopilotGroupTagger.ps1

.EXAMPLE
Pass through Authentication
PS> .\AutopilotGroupTagger.ps1 -tenantId '437e8ffb-3030-469a-99da-e5b527908099'

.EXAMPLE
App Authentication
PS> .\AutopilotGroupTagger.ps1 -tenantId '437e8ffb-3030-469a-99da-e5b527908099' -appId '799ebcfa-ca81-4e72-baaf-a35126464d67' -appSecret 'g708Q~uof4xo9dU_1EjGQIuUr0UyBHNZmY2mcdy6'

#>

[CmdletBinding()]

param(

    [Parameter(Mandatory = $false)]
    [String]$tenantId,

    [Parameter(Mandatory = $false)]
    [String]$appId,

    [Parameter(Mandatory = $false)]
    [String]$appSecret

)

#region Functions
Function Connect-ToGraph {
    <#
.SYNOPSIS
Authenticates to the Graph API via the Microsoft.Graph.Authentication module.

.DESCRIPTION
The Connect-ToGraph cmdlet is a wrapper cmdlet that helps authenticate to the Intune Graph API using the Microsoft.Graph.Authentication module. It leverages an Azure AD app ID and app secret for authentication or user-based auth.

.PARAMETER TenantId
Specifies the tenantId from Entra ID to which to authenticate.

.PARAMETER AppId
Specifies the Azure AD app ID (GUID) for the application that will be used to authenticate.

.PARAMETER AppSecret
Specifies the Azure AD app secret corresponding to the app ID that will be used to authenticate.

.PARAMETER Scopes
Specifies the user scopes for interactive authentication.

.EXAMPLE
Connect-ToGraph -tenantId $tenantId -appId $app -appSecret $secret

-#>

    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory = $false)] [string]$tenantId,
        [Parameter(Mandatory = $false)] [string]$appId,
        [Parameter(Mandatory = $false)] [string]$appSecret,
        [Parameter(Mandatory = $false)] [string[]]$scopes
    )

    Process {
        Import-Module Microsoft.Graph.Authentication
        $version = (Get-Module microsoft.graph.authentication | Select-Object -ExpandProperty Version).major

        if ($AppId -ne '') {
            $body = @{
                grant_type    = 'client_credentials';
                client_id     = $appId;
                client_secret = $appSecret;
                scope         = 'https://graph.microsoft.com/.default';
            }

            $response = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" -Body $body
            $accessToken = $response.access_token

            if ($version -eq 2) {
                Write-Host 'Version 2 module detected'
                $accessTokenFinal = ConvertTo-SecureString -String $accessToken -AsPlainText -Force
            }
            else {
                Write-Host 'Version 1 Module Detected'
                Select-MgProfile -Name Beta
                $accessTokenFinal = $accessToken
            }
            $graph = Connect-MgGraph -AccessToken $accessTokenFinal
            Write-Host "Connected to Intune tenant $TenantId using app-based authentication (Azure AD authentication not supported)"
        }
        else {
            if ($version -eq 2) {
                Write-Host 'Version 2 module detected'
            }
            else {
                Write-Host 'Version 1 Module Detected'
                Select-MgProfile -Name Beta
            }
            $graph = Connect-MgGraph -Scopes $scopes -TenantId $tenantId
            Write-Host "Connected to Intune tenant $($graph.TenantId)"
        }
    }
}
Function Get-AutopilotDevices() {

    <#
    .SYNOPSIS
    This function is used to get autopilot devices via the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any autopilot devices
    .EXAMPLE
    Get-AutopilotDevices
    Returns any autopilot devices
    .NOTES
    NAME: Get-AutopilotDevices
    #>

    $graphApiVersion = 'Beta'
    $Resource = 'deviceManagement/windowsAutopilotDeviceIdentities'

    try {

        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
        $graphResults = Invoke-MgGraphRequest -Uri $uri -Method Get

        $results = @()
        $results += $graphResults.value

        $pages = $graphResults.'@odata.nextLink'
        while ($null -ne $pages) {

            $additional = Invoke-MgGraphRequest -Uri $pages -Method Get

            if ($pages) {
                $pages = $additional.'@odata.nextLink'
            }
            $results += $additional.value
        }
        $results

    }

    catch {

        Write-Error $Error[0].ErrorDetails.Message
        break

    }

}
Function Set-AutopilotDevice() {

    <#
    .SYNOPSIS
    This function is used to set autopilot devices properties via the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and sets autopilot device properties
    .EXAMPLE
    Set-AutopilotDevice
    Returns any autopilot devices
    .NOTES
    NAME: Set-AutopilotDevice
    #>

    [CmdletBinding()]
    param(
        $Id,
        $groupTag
    )

    $graphApiVersion = 'Beta'
    $Resource = "deviceManagement/windowsAutopilotDeviceIdentities/$Id/updateDeviceProperties"

    try {

        if (!$id) {
            Write-Host 'No Autopilot device Id specified, specify a valid Autopilot device Id' -f Red
            break
        }

        if (!$groupTag) {
            $groupTag = Read-Host 'No Group Tag specified, specify a Group Tag'
        }

        $Autopilot = New-Object -TypeName psobject
        $Autopilot | Add-Member -MemberType NoteProperty -Name 'groupTag' -Value $groupTag

        $JSON = $Autopilot | ConvertTo-Json -Depth 3
        # POST to Graph Service
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
        Invoke-MgGraphRequest -Uri $uri -Method Post -Body $JSON -ContentType 'application/json'

    }

    catch {

        Write-Error $Error[0].ErrorDetails.Message
        break

    }

}
Function Get-EntraIDObject() {

    [cmdletbinding()]
    param
    (

        [parameter(Mandatory = $true)]
        [ValidateSet('User', 'Device')]
        $object

    )

    $graphApiVersion = 'beta'
    if ($object -eq 'User') {
        $Resource = "users?`$filter=userType eq 'member' and accountEnabled eq true"
    }
    else {
        $Resource = "devices?`$filter=operatingSystem eq 'Windows'"
    }

    try {

        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"
        $graphResults = Invoke-MgGraphRequest -Uri $uri -Method Get

        $results = @()
        $results += $graphResults.value

        $pages = $graphResults.'@odata.nextLink'
        while ($null -ne $pages) {

            $additional = Invoke-MgGraphRequest -Uri $pages -Method Get

            if ($pages) {
                $pages = $additional.'@odata.nextLink'
            }
            $results += $additional.value
        }
        $results
    }
    catch {
        Write-Error $Error[0].ErrorDetails.Message
        break
    }
}
Function Get-ManagedDevices() {

    [cmdletbinding()]
    param
    (

    )

    $graphApiVersion = 'beta'
    $Resource = "deviceManagement/managedDevices?`$filter=operatingSystem eq 'Windows'"

    try {

        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"
        $graphResults = Invoke-MgGraphRequest -Uri $uri -Method Get

        $results = @()
        $results += $graphResults.value

        $pages = $graphResults.'@odata.nextLink'
        while ($null -ne $pages) {

            $additional = Invoke-MgGraphRequest -Uri $pages -Method Get

            if ($pages) {
                $pages = $additional.'@odata.nextLink'
            }
            $results += $additional.value
        }
        $results
    }
    catch {
        Write-Error $Error[0].ErrorDetails.Message
        break
    }
}
#endregion Functions

#region intro
Write-Host '
 _______         __                __ __         __
|   _   |.--.--.|  |_.-----.-----.|__|  |.-----.|  |_
|       ||  |  ||   _|  _  |  _  ||  |  ||  _  ||   _|
|___|___||_____||____|_____|   __||__|__||_____||____|
                           |__|
' -ForegroundColor Cyan
Write-Host '
 _______                          _______
|     __|.----.-----.--.--.-----.|_     _|.---.-.-----.-----.-----.----.
|    |  ||   _|  _  |  |  |  _  |  |   |  |  _  |  _  |  _  |  -__|   _|
|_______||__| |_____|_____|   __|  |___|  |___._|___  |___  |_____|__|
                          |__|                  |_____|_____|
' -ForegroundColor Red

Write-Host 'Autopilot GroupTagger - Update Autopilot Device Group Tags in bulk.' -ForegroundColor Green
Write-Host 'Nick Benton - oddsandendpoints.co.uk' -NoNewline;
Write-Host ' | Version' -NoNewline; Write-Host ' 0.4 Public Preview' -ForegroundColor Yellow -NoNewline
Write-Host ' | Last updated: ' -NoNewline; Write-Host '2025-02-03' -ForegroundColor Magenta
Write-Host ''
Write-Host 'If you have any feedback, please open an issue at https://github.com/ennnbeee/AutopilotGroupTagger/issues' -ForegroundColor Cyan
Write-Host ''
#endregion intro

#region variables
$requiredScopes = @('Device.Read.All', 'DeviceManagementServiceConfig.ReadWrite.All', 'DeviceManagementManagedDevices.Read.All')
[String[]]$scopes = $requiredScopes -join ', '
#endregion variables

#region module check
$graphModule = 'Microsoft.Graph.Authentication'
Write-Host "Checking for $graphModule PowerShell module..." -ForegroundColor Cyan

If (!(Find-Module -Name $graphModule)) {
    Install-Module -Name $graphModule -Scope CurrentUser -AllowClobber
}
Write-Host "PowerShell Module $graphModule found." -ForegroundColor Green

if (!([System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object FullName -Like "*$graphModule*")) {
    Import-Module -Name $graphModule -Force
}
#endregion module check

#region app auth
try {
    if (!$tenantId) {
        Write-Host 'Connecting using interactive authentication' -ForegroundColor Yellow
        Connect-MgGraph -Scopes $scopes -NoWelcome -ErrorAction Stop
    }
    else {
        if ((!$appId -and !$appSecret) -or ($appId -and !$appSecret) -or (!$appId -and $appSecret)) {
            Write-Host 'Missing App Details, connecting using user authentication' -ForegroundColor Yellow
            Connect-ToGraph -tenantId $tenantId -Scopes $scopes -ErrorAction Stop
        }
        else {
            Write-Host 'Connecting using App authentication' -ForegroundColor Yellow
            Connect-ToGraph -tenantId $tenantId -appId $appId -appSecret $appSecret -ErrorAction Stop
        }
    }
    Write-Host 'Successfully connected to Microsoft Graph.' -ForegroundColor Green
}
catch {
    Write-Error $_.Exception.Message
    Exit
}
#endregion app auth

#region scopes
$context = Get-MgContext
$currentScopes = $context.Scopes

# Validate required permissions
$missingScopes = $requiredScopes | Where-Object { $_ -notin $currentScopes }
if ($missingScopes.Count -gt 0) {
    Write-Host 'WARNING: The following scope permissions are missing:' -ForegroundColor Red
    $missingScopes | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
    Write-Host 'Please ensure these permissions are granted to the app registration for full functionality.' -ForegroundColor Yellow
    exit
}
Write-Host 'All required scope permissions are present.' -ForegroundColor Green
#endregion scopes

#region discovery
Start-Sleep -Seconds 2  # Delay to allow for Graph API to catch up
Write-Host ''
Write-Host 'Getting all Entra ID Windows computer objects...' -ForegroundColor Cyan
$entraDevices = Get-EntraIDObject -object Device
$entraDevicesHash = @{}
foreach ($entraDevice in $entraDevices) {
    $entraDevicesHash[$entraDevice.deviceid] = $entraDevice
}
Write-Host "Found $($entraDevices.Count) Windows devices and associated IDs from Entra ID." -ForegroundColor Green

Write-Host ''
Write-Host 'Getting all Windows Intune devices...' -ForegroundColor Cyan
$intuneDevices = Get-ManagedDevices
$intuneDevicesHash = @{}
foreach ($intuneDevice in $intuneDevices) {
    $intuneDevicesHash[$intuneDevice.id] = $intuneDevice
}
Write-Host "Found $($intuneDevices.Count) Windows device objects and associated IDs from Microsoft Intune." -ForegroundColor Green
Write-Host ''

Write-Host 'Getting all Windows Autopilot devices...' -ForegroundColor Cyan
$apDevices = Get-AutopilotDevices
$autopilotDevices = @()
foreach ($apDevice in $apDevices) {
    # Details of Entra ID device object
    $entraObject = $entraDevicesHash[$apDevice.azureAdDeviceId]
    # Details of Intune device object
    #$intuneObject = $intuneDevicesHash[$apDevice.managedDeviceId]

    $autopilotDevices += [PSCustomObject]@{
        'displayName'      = $entraObject.displayName
        'serialNumber'     = $apDevice.serialNumber
        'manufacturer'     = $apDevice.manufacturer
        'model'            = $apDevice.model
        'enrolmentState'   = $apDevice.enrollmentState
        'enrolmentProfile' = $entraObject.enrollmentProfileName
        'enrolmentType'    = $entraObject.enrollmentType
        'groupTag'         = $apDevice.groupTag
        'purchaseOrder'    = $apDevice.purchaseOrderIdentifier
        'Id'               = $apDevice.Id
    }
}
$autopilotDevicesHash = @{}
foreach ($autopilotDevice in $autopilotDevices) {
    $autopilotDevicesHash[$autopilotDevice.id] = $autopilotDevice
}
Write-Host "Found $($autopilotDevices.Count) Windows Autopilot Devices from Microsoft Intune." -ForegroundColor Green
#endregion discovery

#region Script
while ($autopilotUpdateDevices.Count -eq 0) {

    Write-Host
    Write-Host 'Please Choose one of the Group Tag options below: ' -ForegroundColor Magenta
    Write-Host
    Write-Host ' (1) Update All Autopilot Devices Group Tags'
    Write-Host
    Write-Host ' (2) Update All Autopilot Devices with Empty Group Tags'
    Write-Host
    Write-Host ' (3) Update All Autopilot Devices with a specific Group Tag'
    Write-Host
    Write-Host ' (4) Update All selected Manufacturers of Autopilot Device Group Tags'
    Write-Host
    Write-Host ' (5) Update All selected Models of Autopilot Device Group Tags'
    Write-Host
    Write-Host ' (6) Update All Autopilot Devices with a specific Purchase Order'
    Write-Host
    Write-Host ' (7) Update a selection of Autopilot Devices Group Tags interactively'
    Write-Host
    Write-Host ' (8) Update Autopilot Devices Group Tags using exported data'
    Write-Host
    Write-Host ' (E) EXIT SCRIPT ' -ForegroundColor Red
    Write-Host
    $choice = ''
    $autopilotUpdateDevices = @()
    $choice = Read-Host -Prompt 'Please select an option from the provided list, then press enter'
    while ( $choice -notin @('1', '2', '3', '4', '5', '6', '7', '8', 'E')) {
        $choice = Read-Host -Prompt 'Please select an option from the provided list, then press enter'
    }
    if ($choice -eq 'E') {
        Exit
    }
    if ($choice -eq '1') {
        #All AutoPilot Devices
        $autopilotUpdateDevices = $autopilotDevices
    }
    if ($choice -eq '2') {
        #All AutoPilot Devices with Empty Group Tags
        $autopilotUpdateDevices = $autopilotDevices | Where-Object { ($null -eq $_.groupTag) -or ($_.groupTag) -eq '' }
        if ($autopilotUpdateDevices.count -eq 0) {
            Write-Host
            Write-Host 'No Autopilot Devices with Empty Group Tags found.' -ForegroundColor Yellow
            Write-Host
            Write-Host 'Please select another option.' -ForegroundColor Yellow
            Write-Host
            continue
        }
    }
    if ($choice -eq '3') {
        # GroupTag prompts
        while ($autopilotGroupTags.count -eq 0) {
            $autopilotGroupTags = @($autopilotDevices | Select-Object -Property groupTag -Unique | Out-GridView -PassThru -Title 'Select GroupTags of Autopilot Devices to Update')
        }

        $autopilotUpdateDevices = $autopilotDevices | Where-Object { $_.groupTag -in $autopilotGroupTags.groupTag }
    }
    if ($choice -eq '4') {
        # Manufacturer prompts
        while ($autopilotManufacturers.count -eq 0) {
            $autopilotManufacturers = @($autopilotDevices | Select-Object -Property manufacturer -Unique | Out-GridView -PassThru -Title 'Select Manufacturer of Autopilot Devices to Update')
        }

        $autopilotUpdateDevices = $autopilotDevices | Where-Object { $_.manufacturer -in $autopilotManufacturers.manufacturer }
    }
    if ($choice -eq '5') {
        # Model prompts
        while ($autopilotModels.count -eq 0) {
            $autopilotModels = @($autopilotDevices | Select-Object -Property model -Unique | Out-GridView -PassThru -Title 'Select Models of Autopilot Devices to Update')
        }

        $autopilotUpdateDevices = $autopilotDevices | Where-Object { $_.model -in $autopilotModels.model }
    }
    if ($choice -eq '6') {
        # Purchase Order prompts
        while ($autopilotPOs.count -eq 0) {
            $autopilotPOs = @($autopilotDevices | Select-Object -Property purchaseOrder -Unique | Out-GridView -PassThru -Title 'Select Purchase Order of Autopilot Devices to Update')
        }
        $autopilotUpdateDevices = $autopilotDevices | Where-Object { $_.purchaseOrder -in $autopilotPOs.purchaseOrder }
    }
    if ($choice -eq '7') {
        while ($autopilotUpdateDevices.count -eq 0) {
            $autopilotUpdateDevices = @($autopilotDevices | Out-GridView -PassThru -Title 'Select Autopilot Devices to Update')
        }
    }
    if ($choice -eq '8') {
        # Report
        $autopilotDevices | Export-Csv -Path '.\AutopilotDevices.csv' -NoTypeInformation -Force
        while ($autopilotUpdateDevices.count -eq 0) {
            Write-Host 'Exported All Autopilot Devices to AutopilotDevices.csv' -ForegroundColor Cyan
            Write-Warning -Message 'Please update the Group Tags on devices in AutopilotDevices.csv before continuing' -WarningAction Inquire
            $autopilotImportDevices = Import-Csv -Path .\AutopilotDevices.csv
            foreach ($autopilotImportDevice in $autopilotImportDevices) {
                $apObject = $autopilotDevicesHash[$autopilotImportDevice.Id]
                if ($autopilotImportDevice.groupTag -ne $apObject.groupTag) {
                    $autopilotUpdateDevices += $autopilotImportDevice
                }
            }
        }
    }
}

if ($choice -ne '8') {
    [string]$groupTagNew = Read-Host "Please enter the NEW group tag you wish to apply to the $($autopilotUpdateDevices.Count) Autopilot devices"
    while ($groupTagNew -eq '' -or $null -eq $groupTagNew) {
        [string]$groupTagNew = Read-Host "Please enter the NEW group tag you wish to apply to the $($autopilotUpdateDevices.Count) Autopilot devices"
    }
}

Write-Host "The following $($autopilotUpdateDevices.Count) Autopilot devices are in scope to be updated:" -ForegroundColor Yellow
$autopilotUpdateDevices | Format-Table -Property displayName, serialNumber, manufacturer, model, purchaseOrder -AutoSize

Write-Warning -Message "You are about to update the group tag for $($autopilotUpdateDevices.Count) Autopilot devices." -WarningAction Inquire

foreach ($autopilotUpdateDevice in $autopilotUpdateDevices) {
    $rndWait = Get-Random -Minimum 0 -Maximum 2

    if ($choice -eq '8') {
        $groupTagNew = $($autopilotUpdateDevice.groupTag)
    }

    Write-Host "Updating Autopilot Group Tag with Serial Number: $($autopilotUpdateDevice.serialNumber) to '$groupTagNew'." -ForegroundColor Cyan
    Start-Sleep -Seconds $rndWait
    Set-AutopilotDevice -id $autopilotUpdateDevice.id -groupTag $groupTagNew
    Write-Host "Updated Autopilot Group Tag with Serial Number: $($autopilotUpdateDevice.serialNumber) to '$groupTagNew'." -ForegroundColor Green
}

Write-Host "Successfully updated $($autopilotUpdateDevices.Count) Autopilot devices with the new group tag" -ForegroundColor Green
#endregion Script