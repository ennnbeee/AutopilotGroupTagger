<#PSScriptInfo

.VERSION 0.4.3
.GUID 63c8809e-5c8a-4ddc-82a4-29706992802f
.AUTHOR Nick Benton
.COMPANYNAME
.COPYRIGHT GPL
.TAGS
.LICENSEURI https://github.com/ennnbeee/AutopilotGroupTagger/blob/main/LICENSE
.PROJECTURI https://github.com/ennnbeee/AutopilotGroupTagger
.ICONURI
.EXTERNALMODULEDEPENDENCIES
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
Version 0.4.3: Improvements to user interface and error handling
Version 0.4.2: Bug fixes and improvements
Version 0.4.1: Updated authentication and module detection
Version 0.4: Configured to run on PowerShell 5
Version 0.3: Updated logic around Autopilot device selection
Version 0.2: Included functionality to update group tags based on Purchase order
Version 0.1: Initial release
.PRIVATEDATA
#>

<#
.SYNOPSIS
Autopilot GroupTagger - Update Autopilot Device Group Tags in bulk.

.DESCRIPTION
The Autopilot GroupTagger script is designed to allow for bulk updating of Autopilot device group tags in Microsoft Intune.
The script will connect to the Microsoft Graph API and retrieve all Autopilot devices, then allow for bulk updating of group tags based on various criteria.

.PARAMETER tenantId
Provide the Id of the Entra ID tenant to connect to.

.PARAMETER appId
Provide the Id of the Entra App registration to be used for authentication.

.PARAMETER appSecret
Provide the App secret to allow for authentication to graph

.EXAMPLE
Interactive Authentication
.\AutopilotGroupTagger.ps1

.EXAMPLE
Pass through Authentication
.\AutopilotGroupTagger.ps1 -tenantId '437e8ffb-3030-469a-99da-e5b527908099'

.EXAMPLE
App Authentication
.\AutopilotGroupTagger.ps1 -tenantId '437e8ffb-3030-469a-99da-e5b527908099' -appId '799ebcfa-ca81-4e72-baaf-a35126464d67' -appSecret 'g708Q~uof4xo9dU_1EjGQIuUr0UyBHNZmY2mcdy6'

#>

[CmdletBinding(DefaultParameterSetName = 'Default')]

param(

    [Parameter(Mandatory = $false, HelpMessage = 'Provide the Id of the Entra ID tenant to connect to')]
    [ValidateLength(36, 36)]
    [String]$tenantId,

    [Parameter(Mandatory = $false, ParameterSetName = 'appAuth', HelpMessage = 'Provide the Id of the Entra App registration to be used for authentication')]
    [ValidateLength(36, 36)]
    [String]$appId,

    [Parameter(Mandatory = $true, ParameterSetName = 'appAuth', HelpMessage = 'Provide the App secret to allow for authentication to graph')]
    [ValidateNotNullOrEmpty()]
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
        Write-Error $_.Exception.Message
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
        [Parameter(Mandatory = $true)]
        $Id,

        [Parameter(Mandatory = $true)]
        $groupTag
    )

    $graphApiVersion = 'Beta'
    $Resource = "deviceManagement/windowsAutopilotDeviceIdentities/$Id/updateDeviceProperties"

    try {
        $Autopilot = New-Object -TypeName psobject
        $Autopilot | Add-Member -MemberType NoteProperty -Name 'groupTag' -Value $groupTag

        $JSON = $Autopilot | ConvertTo-Json -Depth 3
        # POST to Graph Service
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
        Invoke-MgGraphRequest -Uri $uri -Method Post -Body $JSON -ContentType 'application/json'
    }
    catch {
        Write-Error $_.Exception.Message
        break
    }
}
Function Get-EntraIDObject() {

    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param
    (

        [parameter(Mandatory = $false)]
        [switch]$user,

        [parameter(Mandatory = $false, ParameterSetName = 'devices')]
        [switch]$device,

        [parameter(Mandatory = $true)]
        [ValidateSet('Windows', 'iOS', 'Android', 'macOS')]
        [string]$os

    )

    $graphApiVersion = 'beta'
    if ($user) {
        $Resource = "users?`$filter=userType eq 'member' and accountEnabled eq true"
    }
    else {
        switch ($os) {
            'iOS' {
                $Resource = "devices?`$filter=operatingSystem eq 'iOS'"
            }
            'Android' {
                $Resource = "devices?`$filter=operatingSystem eq 'Android'"
            }
            'macOS' {
                $Resource = "devices?`$filter=operatingSystem eq 'macOS'"
            }
            'Windows' {
                $Resource = "devices?`$filter=operatingSystem eq 'Windows'"
            }
        }
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
        [parameter(Mandatory = $true)]
        [ValidateSet('Windows', 'iOS', 'Android', 'macOS')]
        [string]$os
    )

    $graphApiVersion = 'beta'
    switch ($os) {
        'iOS' {
            $Resource = "deviceManagement/managedDevices?`$filter=operatingSystem eq 'iOS'"
        }
        'Android' {
            $Resource = "deviceManagement/managedDevices?`$filter=operatingSystem eq 'Android'"
        }
        'macOS' {
            $Resource = "deviceManagement/managedDevices?`$filter=operatingSystem eq 'macOS'"
        }
        'Windows' {
            $Resource = "deviceManagement/managedDevices?`$filter=operatingSystem eq 'Windows'"
        }
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
Function Read-YesNoChoice {
    <#
        .SYNOPSIS
        Prompt the user for a Yes No choice.

        .DESCRIPTION
        Prompt the user for a Yes No choice and returns 0 for no and 1 for yes.

        .PARAMETER Title
        Title for the prompt

        .PARAMETER Message
        Message for the prompt

		.PARAMETER DefaultOption
        Specifies the default option if nothing is selected

        .INPUTS
        None. You cannot pipe objects to Read-YesNoChoice.

        .OUTPUTS
        Int. Read-YesNoChoice returns an Int, 0 for no and 1 for yes.

        .EXAMPLE
        PS> $choice = Read-YesNoChoice -Title "Please Choose" -Message "Yes or No?"

		Please Choose
		Yes or No?
		[N] No  [Y] Yes  [?] Help (default is "N"): y
		PS> $choice
        1

		.EXAMPLE
        PS> $choice = Read-YesNoChoice -Title "Please Choose" -Message "Yes or No?" -DefaultOption 1

		Please Choose
		Yes or No?
		[N] No  [Y] Yes  [?] Help (default is "Y"):
		PS> $choice
        1

        .LINK
        Online version: https://www.chriscolden.net/2024/03/01/yes-no-choice-function-in-powershell/
    #>

    Param (
        [Parameter(Mandatory = $true)][String]$Title,
        [Parameter(Mandatory = $true)][String]$Message,
        [Parameter(Mandatory = $false)][Int]$DefaultOption = 0
    )

    $No = New-Object System.Management.Automation.Host.ChoiceDescription '&No', 'No'
    $Yes = New-Object System.Management.Automation.Host.ChoiceDescription '&Yes', 'Yes'
    $Options = [System.Management.Automation.Host.ChoiceDescription[]]($No, $Yes)

    return $host.ui.PromptForChoice($Title, $Message, $Options, $DefaultOption)
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
Write-Host ' | Version' -NoNewline; Write-Host ' 0.4.3 Public Preview' -ForegroundColor Yellow -NoNewline
Write-Host ' | Last updated: ' -NoNewline; Write-Host '2025-02-06' -ForegroundColor Magenta
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

If (!(Get-Module -Name $graphModule -ListAvailable)) {
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
$entraDevices = Get-EntraIDObject -device -os Windows
$entraDevicesHash = @{}
foreach ($entraDevice in $entraDevices) {
    $entraDevicesHash[$entraDevice.deviceid] = $entraDevice
}
Write-Host "Found $($entraDevices.Count) Windows devices and associated IDs from Entra ID." -ForegroundColor Green

Write-Host ''
Write-Host 'Getting all Windows Intune devices...' -ForegroundColor Cyan
$intuneDevices = Get-ManagedDevices -os Windows
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

#region choices
while ($autopilotUpdateDevices.Count -eq 0) {

    Write-Host ''
    Write-Host 'Please Choose one of the Group Tag options below: ' -ForegroundColor Magenta
    Write-Host ''
    Write-Host ' (1) Update All Autopilot Devices Group Tags'
    Write-Host ''
    Write-Host ' (2) Update All Autopilot Devices with Empty Group Tags'
    Write-Host ''
    Write-Host ' (3) Update All Autopilot Devices with a specific Group Tag'
    Write-Host ''
    Write-Host ' (4) Update All selected Manufacturers of Autopilot Device Group Tags'
    Write-Host ''
    Write-Host ' (5) Update All selected Models of Autopilot Device Group Tags'
    Write-Host ''
    Write-Host ' (6) Update All Autopilot Devices with a specific Purchase Order'
    Write-Host ''
    Write-Host ' (7) Update a selection of Autopilot Devices Group Tags interactively'
    Write-Host ''
    Write-Host ' (8) Update Autopilot Devices Group Tags using exported data'
    Write-Host ''
    Write-Host ' (E) EXIT SCRIPT ' -ForegroundColor Red
    Write-Host ''
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
        $confirmGroupTags = 0
        while ($confirmGroupTags -ne 1) {
            while ($autopilotGroupTags.count -eq 0) {
                $autopilotGroupTags = @($autopilotDevices | Select-Object -Property groupTag -Unique | Out-GridView -PassThru -Title 'Select GroupTags of Autopilot Devices to Update')
            }
            Write-Host ''
            Write-Host 'The following Group Tag(s) were selected:' -ForegroundColor Cyan
            Write-Host ''
            $autopilotGroupTags.groupTag
            Write-Host ''
            $confirmGroupTags = Read-YesNoChoice -Title 'Please confirm Group Tag(s) selection' -Message 'Are these the correct Group Tag(s) to update?' -DefaultOption 1
            if ($confirmGroupTags -eq 0) {
                Write-Host ''
                Write-Host 'Please re-select the Group Tags to update' -ForegroundColor Yellow
                $autopilotGroupTags = $null
            }
            $autopilotUpdateDevices = $autopilotDevices | Where-Object { $_.groupTag -in $autopilotGroupTags.groupTag }
        }
    }
    if ($choice -eq '4') {
        # Manufacturer prompts
        $confirmManufacturers = 0
        while ($confirmManufacturers -ne 1) {
            while ($autopilotManufacturers.count -eq 0) {
                $autopilotManufacturers = @($autopilotDevices | Select-Object -Property manufacturer -Unique | Out-GridView -PassThru -Title 'Select Manufacturer of Autopilot Devices to Update')
            }
            Write-Host ''
            Write-Host 'The following Autopilot Device Manufacturer(s) were selected:' -ForegroundColor Cyan
            Write-Host ''
            $autopilotManufacturers.manufacturer
            Write-Host ''
            $confirmManufacturers = Read-YesNoChoice -Title 'Please confirm the Autopilot Device Manufacturer(s)' -Message 'Are these the correct Manufacturer(s) to update?' -DefaultOption 1
            if ($confirmManufacturers -eq 0) {
                Write-Host ''
                Write-Host 'Please re-select the Manufacturer(s) to update' -ForegroundColor Yellow
                $autopilotManufacturers = $null
            }
            $autopilotUpdateDevices = $autopilotDevices | Where-Object { $_.manufacturer -in $autopilotManufacturers.manufacturer }
        }
    }
    if ($choice -eq '5') {
        # Model prompts
        $confirmModels = 0
        while ($confirmModels -ne 1) {
            while ($autopilotModels.count -eq 0) {
                $autopilotModels = @($autopilotDevices | Select-Object -Property model -Unique | Out-GridView -PassThru -Title 'Select Models of Autopilot Devices to Update')
            }
            Write-Host ''
            Write-Host 'The following Autopilot Device Model(s) were selected:' -ForegroundColor Cyan
            Write-Host ''
            $autopilotModels.model
            Write-Host ''
            $confirmModels = Read-YesNoChoice -Title 'Please confirm the Autopilot Device Model(s)' -Message 'Are these the correct Model(s) to update?' -DefaultOption 1
            if ($confirmModels -eq 0) {
                Write-Host ''
                Write-Host 'Please re-select the Models to update' -ForegroundColor Yellow
                $autopilotModels = $null
            }
            $autopilotUpdateDevices = $autopilotDevices | Where-Object { $_.model -in $autopilotModels.model }
        }
    }
    if ($choice -eq '6') {
        # Purchase Order prompts
        $confirmPOs = 0
        while ($confirmPOs -ne 1) {
            while ($autopilotPOs.count -eq 0) {
                $autopilotPOs = @($autopilotDevices | Select-Object -Property purchaseOrder -Unique | Out-GridView -PassThru -Title 'Select Purchase Order of Autopilot Devices to Update')
            }
            Write-Host ''
            Write-Host 'The following Autopilot Device Purchase Order(s) were selected:' -ForegroundColor Cyan
            Write-Host ''
            $autopilotPOs.purchaseOrder
            Write-Host ''
            $confirmPOs = Read-YesNoChoice -Title 'Please confirm Autopilot Device Purchase Order(s)' -Message 'Are these the correct Purchase Order(s) to update?' -DefaultOption 1
            if ($confirmPOs -eq 0) {
                Write-Host ''
                Write-Host 'Please re-select the Purchase Order(s) to update' -ForegroundColor Yellow
                $autopilotPOs = $null
            }
            $autopilotUpdateDevices = $autopilotDevices | Where-Object { $_.purchaseOrder -in $autopilotPOs.purchaseOrder }
        }
    }
    if ($choice -eq '7') {
        while ($autopilotUpdateDevices.count -eq 0) {
            $autopilotUpdateDevices = @($autopilotDevices | Out-GridView -PassThru -Title 'Select Autopilot Devices to Update')
        }
    }
    if ($choice -eq '8') {
        # Report
        $autopilotDevices | Export-Csv -Path '.\AutopilotDevices.csv' -NoTypeInformation -Force
        Write-Host ''
        Write-Host 'Exported All Autopilot Device(s) to AutopilotDevices.csv' -ForegroundColor Cyan
        while ($autopilotUpdateDevices.count -eq 0 -or ($autopilotUpdateDevices.groupTag | Measure-Object -Maximum).Maximum.length -gt 512) {
            Write-Host ''
            if (($autopilotUpdateDevices.groupTag | Measure-Object -Maximum).Maximum.length -gt 512) {
                Write-Host 'One or more Group Tags are greater than 512 characters.' -ForegroundColor Red
                Write-Host ''
            }
            Write-Warning -Message 'Please update the Group Tags on device(s) in AutopilotDevices.csv and save the file before continuing' -WarningAction Inquire
            $autopilotImportDevices = Import-Csv -Path .\AutopilotDevices.csv
            $autopilotUpdateDevices = @()
            foreach ($autopilotImportDevice in $autopilotImportDevices) {
                $apObject = $autopilotDevicesHash[$autopilotImportDevice.Id]
                if ($autopilotImportDevice.groupTag -ne $apObject.groupTag) {
                    $autopilotUpdateDevices += $autopilotImportDevice
                }
            }
        }
    }
}
#endregion choices

#region group tag prompt
if ($choice -ne '8') {
    Write-Host ''
    [string]$groupTagNew = Read-Host "Please enter the *NEW* group tag you wish to apply to the $($autopilotUpdateDevices.Count) Autopilot device(s)"
    while ($groupTagNew -eq '' -or $null -eq $groupTagNew) {
        [string]$groupTagNew = Read-Host "Please enter the *NEW* group tag you wish to apply to the $($autopilotUpdateDevices.Count) Autopilot device(s)"
    }
    #group tags have a maximum of 512 characters
    while ($groupTagNew.length -gt 512) {
        [string]$groupTagNew = Read-Host "Please enter the *NEW* group tag you wish to apply to the $($autopilotUpdateDevices.Count) Autopilot device(s) but with less than 512 characters"
    }
}
#endregion group tag prompt

#region group tag update
Write-Host ''
Write-Host "The following $($autopilotUpdateDevices.Count) Autopilot device(s) are in scope to be updated:" -ForegroundColor Yellow
$autopilotUpdateDevices | Format-Table -Property displayName, serialNumber, manufacturer, model, purchaseOrder -AutoSize

Write-Warning -Message "You are about to update the group tag(s) for $($autopilotUpdateDevices.Count) Autopilot device(s)." -WarningAction Inquire

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
Write-Host ''
Write-Host "Successfully updated $($autopilotUpdateDevices.Count) Autopilot device(s) with the new group tag(s)" -ForegroundColor Green
#endregion group tag update
