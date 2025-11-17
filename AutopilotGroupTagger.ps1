<#PSScriptInfo

.VERSION 0.7.0
.GUID 63c8809e-5c8a-4ddc-82a4-29706992802f
.AUTHOR Nick Benton
.COMPANYNAME
.COPYRIGHT GPL
.TAGS Graph Intune Windows Autopilot GroupTags
.LICENSEURI https://github.com/ennnbeee/AutopilotGroupTagger/blob/main/LICENSE
.PROJECTURI https://github.com/ennnbeee/AutopilotGroupTagger
.ICONURI https://raw.githubusercontent.com/ennnbeee/AutopilotGroupTagger/refs/heads/main/img/agt-icon.png
.EXTERNALMODULEDEPENDENCIES Microsoft.Graph.Authentication
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
v0.7.0 - Updated to support re-running of the script and other bug fixes
v0.6.0 - Supports unblocking of Autopilot devices
v0.5.0 - Now supports PowerShell 7 on macOS, removal of Group Tags, and Dynamic Group creation
v0.4.5 - Function rework to support PowerShell gallery requirements
v0.4.4 - Added 'WhatIf' mode, and updated user experience of output of the progress of Group Tag updates
v0.4.3 - Improvements to user interface and error handling
v0.4.2 - Bug fixes and improvements
v0.4.1 - Updated authentication and module detection
v0.4.0 - Configured to run on PowerShell 5
v0.3.0 - Updated logic around Autopilot device selection
v0.2.0 - Included functionality to update group tags based on Purchase order
v0.1.0 - Initial release

.PRIVATEDATA
#>

<#
.SYNOPSIS
Autopilot GroupTagger - Update Autopilot Device Group Tags in bulk.

.DESCRIPTION
The Autopilot GroupTagger script is designed to allow for bulk updating of Autopilot device group tags in Microsoft Intune.
The script will connect to the Microsoft Graph API and retrieve all Autopilot devices, then allow for bulk updating of group tags based on various criteria.

.PARAMETER whatIf
Switch to enable WhatIf mode to simulate changes.

.PARAMETER createGroups
Switch to enable the creation of dynamic groups based on Group Tags.

.PARAMETER groupPrefix
Provide the prefix to be used for the creation of dynamic groups. Default is 'AGT-Autopilot-'.

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

    [Parameter(Mandatory = $false, HelpMessage = 'Switch to enable the creation of dynamic groups based on Group Tags')]
    [switch]$createGroups,

    [Parameter(Mandatory = $false, HelpMessage = 'Provide the prefix to be used for the creation of dynamic groups')]
    [String]$groupPrefix = 'AGT-Autopilot-',

    [Parameter(Mandatory = $false, HelpMessage = 'Provide the Id of the Entra ID tenant to connect to')]
    [ValidateLength(36, 36)]
    [String]$tenantId,

    [Parameter(Mandatory = $false, ParameterSetName = 'appAuth', HelpMessage = 'Provide the Id of the Entra App registration to be used for authentication')]
    [ValidateLength(36, 36)]
    [String]$appId,

    [Parameter(Mandatory = $true, ParameterSetName = 'appAuth', HelpMessage = 'Provide the App secret to allow for authentication to graph')]
    [ValidateNotNullOrEmpty()]
    [String]$appSecret,

    [Parameter(Mandatory = $false, HelpMessage = 'WhatIf mode to simulate changes')]
    [switch]$whatIf

)

#region Functions
function Test-JSONData {

    <#
    .SYNOPSIS
    Validates JSON data format.

    .DESCRIPTION
    The Test-JSONData function checks if the provided JSON string is in a valid format.

    .PARAMETER JSON
    Specifies the JSON string to validate.

    .EXAMPLE
    Test-JSONData -JSON '{"key": "value"}'
    #>

    param (
        $JSON
    )

    try {
        $TestJSON = ConvertFrom-Json $JSON -ErrorAction Stop
        $TestJSON | Out-Null
        $validJson = $true
    }
    catch {
        $validJson = $false
        Write-Error $_.Exception.Message
        break
    }
    if (!$validJson) {
        Write-Error $_.Exception.Message
        break
    }
}
function Connect-ToGraph {
    <#
    .SYNOPSIS
    Authenticates to the Graph API via the Microsoft.Graph.Authentication module.

    .DESCRIPTION
    The Connect-ToGraph cmdlet is a wrapper cmdlet that helps authenticate to the Intune Graph API using the Microsoft.Graph.Authentication module. It leverages an Azure AD app ID and app secret for authentication or user-based auth.

    .PARAMETER tenantId
    Specifies the tenantId from Entra ID to which to authenticate.

    .PARAMETER appId
    Specifies the Azure AD app ID (GUID) for the application that will be used to authenticate.

    .PARAMETER appSecret
    Specifies the Azure AD app secret corresponding to the app ID that will be used to authenticate.

    .PARAMETER scopes
    Specifies the user scopes for interactive authentication.

    .EXAMPLE
    Connect-ToGraph -tenantId $tenantId -appId $appId -appSecret $appSecret

    #>

    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory = $false)] [string]$tenantId,
        [Parameter(Mandatory = $false)] [string]$appId,
        [Parameter(Mandatory = $false)] [string]$appSecret,
        [Parameter(Mandatory = $false)] [string[]]$scopes
    )

    process {
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
function Get-AutopilotDevice() {

    <#
    .SYNOPSIS
    This function is used to get autopilot devices via the Graph API REST interface

    .DESCRIPTION
    The function connects to the Graph API Interface and gets any autopilot devices

    .EXAMPLE
    Get-AutopilotDevice
    Returns any autopilot devices

    #>

    $graphApiVersion = 'Beta'
    $Resource = 'deviceManagement/windowsAutopilotDeviceIdentities'

    try {

        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
        $graphResults = Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject

        $results = @()
        $results += $graphResults.value

        $pages = $graphResults.'@odata.nextLink'
        while ($null -ne $pages) {

            $additional = Invoke-MgGraphRequest -Uri $pages -Method Get -OutputType PSObject

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
function Set-AutopilotDevice() {

    <#
    .SYNOPSIS
    This function is used to set autopilot devices properties via the Graph API REST interface

    .DESCRIPTION
    The function connects to the Graph API Interface and sets autopilot device properties

    .PARAMETER Id
    Specifies the Id of the autopilot device to update.

    .PARAMETER groupTag
    Specifies the group tag to assign to the autopilot device.

    .PARAMETER unblock
    Specifies whether to unblock the autopilot device.

    .EXAMPLE
    Set-AutopilotDevice -Id <Id> -groupTag <groupTag> -unblock $true
    Updates the specified autopilot device with the provided group tag and unblock status.

    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'high')]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Id,

        [Parameter(Mandatory = $false)]
        [string]$groupTag,

        [Parameter(Mandatory = $false)]
        [bool]$unblock
    )

    process {
        $graphApiVersion = 'Beta'
        if ($groupTag) {
            $Resource = "deviceManagement/windowsAutopilotDeviceIdentities/$Id/updateDeviceProperties"
        }
        elseif ($unblock -eq $true) {
            $Resource = "deviceManagement/windowsAutopilotDeviceIdentities/$Id//allowNextEnrollment"
        }

        if ($PSCmdlet.ShouldProcess('Autopilot Device', 'Update')) {
            try {
                $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
                if ($groupTag) {
                    $Autopilot = New-Object -TypeName psobject
                    $Autopilot | Add-Member -MemberType NoteProperty -Name 'groupTag' -Value $groupTag

                    $JSON = $Autopilot | ConvertTo-Json -Depth 3

                    Invoke-MgGraphRequest -Uri $uri -Method Post -Body $JSON -ContentType 'application/json'
                }
                else {
                    Invoke-MgGraphRequest -Uri $uri -Method Post
                }
            }
            catch {
                Write-Error $_.Exception.Message
                break
            }
        }
        elseif ($WhatIfPreference.IsPresent) {
            Write-Output "Autopilot Device $Id would have been updated"
        }
        else {
            Write-Output "Autopilot Device $Id was not updated"
        }
    }

}
function Get-EntraIDObject() {

    <#
    .SYNOPSIS
    This function is used to get Entra ID objects

    .DESCRIPTION
    The function connects to the Graph API Interface and gets any Entra ID objects

    .PARAMETER user
    Specifies whether to retrieve user objects.

    .PARAMETER device
    Specifies whether to retrieve device objects.

    .PARAMETER os
    Specifies the operating system of the device to retrieve.

    .EXAMPLE
    Get-EntraIDObject -device -os Windows
    Returns any Windows Entra ID objects

    #>

    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param
    (

        [parameter(Mandatory = $false)]
        [switch]$user,

        [parameter(Mandatory = $false, ParameterSetName = 'devices')]
        [switch]$device,

        [parameter(Mandatory = $true, ParameterSetName = 'devices')]
        [ValidateSet('Windows', 'iOS', 'Android', 'macOS')]
        [string]$os

    )

    $graphApiVersion = 'beta'
    if ($user) {
        $Resource = "users?`$filter=userType eq 'member' and accountEnabled eq true"
    }
    elseif ($device) {
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
        $graphResults = Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject

        $results = @()
        $results += $graphResults.value

        $pages = $graphResults.'@odata.nextLink'
        while ($null -ne $pages) {

            $additional = Invoke-MgGraphRequest -Uri $pages -Method Get -OutputType PSObject

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
function Get-ManagedDevice() {

    <#
    .SYNOPSIS
    This function is used to get Intune device objects

    .DESCRIPTION
    The function connects to the Graph API Interface and gets any Intune device objects

    .PARAMETER os
    Specifies the operating system of the device to retrieve.

    .EXAMPLE
    Get-ManagedDevice -os Windows
    Returns any Windows Intune device objects

    #>

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
        $graphResults = Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject

        $results = @()
        $results += $graphResults.value

        $pages = $graphResults.'@odata.nextLink'
        while ($null -ne $pages) {

            $additional = Invoke-MgGraphRequest -Uri $pages -Method Get -OutputType PSObject

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
function Get-MDMGroup() {

    <#
    .SYNOPSIS
    This function is used to get Entra ID groups

    .DESCRIPTION
    The function connects to the Graph API Interface and gets any Entra ID groups

    .PARAMETER groupName
    Specifies the name of the group to retrieve.

    .EXAMPLE
    Get-MDMGroup -groupName 'Windows Intune Devices'

    #>

    [cmdletbinding()]

    param
    (
        [parameter(Mandatory = $true)]
        [string]$groupName
    )

    $graphApiVersion = 'beta'
    $Resource = 'groups'

    try {
        $searchTerm = 'search="displayName:' + $groupName + '"'
        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource`?$searchTerm"
        (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject -Headers @{ConsistencyLevel = 'eventual' }).Value
    }
    catch {
        Write-Error $_.Exception.Message
        break
    }
}
function New-MDMGroup() {

    <#
    .SYNOPSIS
    This function is used to create Entra ID groups

    .DESCRIPTION
    The function connects to the Graph API Interface and creates a new Entra ID group

    .PARAMETER JSON
    Specifies the JSON representation of the group to create.

    .EXAMPLE
    New-MDMGroup -JSON $JSONData

    #>

    [cmdletbinding(SupportsShouldProcess, ConfirmImpact = 'low')]

    param
    (
        [Parameter(Mandatory = $true)]
        $JSON
    )

    process {

        $graphApiVersion = 'beta'
        $Resource = 'groups'

        if ($PSCmdlet.ShouldProcess('Entra Group', 'Create')) {
            try {
                Test-JsonData -Json $JSON
                $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
                Invoke-MgGraphRequest -Uri $uri -Method Post -Body $JSON -ContentType 'application/json'
            }
            catch {
                Write-Error $_.Exception.Message
                break
            }
        }
        elseif ($WhatIfPreference.IsPresent) {
            Write-Output 'Entra Group would have been created'
        }
        else {
            Write-Output 'Entra Group was not created'
        }
    }
}
function Read-YesNoChoice {
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

    param (
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

#region variables
$modules = @('Microsoft.Graph.Authentication', 'Microsoft.PowerShell.ConsoleGuiTools')
$requiredScopes = @('Device.Read.All', 'DeviceManagementServiceConfig.ReadWrite.All', 'DeviceManagementManagedDevices.Read.All', 'Group.ReadWrite.All')
[String[]]$scopes = $requiredScopes -join ', '
$rndWait = Get-Random -Minimum 1 -Maximum 2
$continueScript = ''
#endregion variables

#region intro
Write-Host '
 _______         __                __ __         __
|   _   |.--.--.|  |_.-----.-----.|__|  |.-----.|  |_' -ForegroundColor Cyan -NoNewline
Write-Host '
|       ||  |  ||   _|  _  |  _  ||  |  ||  _  ||   _|' -ForegroundColor DarkCyan -NoNewline
Write-Host '
|___|___||_____||____|_____|   __||__|__||_____||____|
                           |__|
' -ForegroundColor blue
Write-Host '
 _______                          _______
|     __|.----.-----.--.--.-----.|_     _|.---.-.-----.-----.-----.----.
|    |  ||   _|  _  |  |  |  _  |  |   |  |  _  |  _  |  _  |  -__|   _|
|_______||__| |_____|_____|   __|  |___|  |___._|___  |___  |_____|__|
                          |__|                  |_____|_____|
' -ForegroundColor Green

Write-Host 'AutopilotGroupTagger - Update Autopilot devices in bulk.' -ForegroundColor Green
Write-Host 'Nick Benton - oddsandendpoints.co.uk' -NoNewline;
Write-Host ' | Version' -NoNewline; Write-Host ' 0.7.0 Public Preview' -ForegroundColor Yellow -NoNewline
Write-Host ' | Last updated: ' -NoNewline; Write-Host '2025-10-08' -ForegroundColor Magenta
Write-Host "`nIf you have any feedback, please open an issue at https://github.com/ennnbeee/AutopilotGroupTagger/issues" -ForegroundColor Cyan
Start-Sleep -Seconds $rndWait
#endregion intro

#region preflight
if ($PSVersionTable.PSVersion.Major -eq 5) {
    Write-Host "`nWARNING: PowerShell 5 is not supported, use PowerShell 7.2 or later." -ForegroundColor Yellow
    exit
}
#endregion preflight

#region module check
foreach ($module in $modules) {
    Write-Host "Checking for $module PowerShell module..." -ForegroundColor Cyan
    if (!(Get-Module -Name $module -ListAvailable)) {
        Install-Module -Name $module -Scope CurrentUser -AllowClobber
    }
    Write-Host "`nPowerShell Module $module found." -ForegroundColor Green
    if (!([System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object FullName -Like "*$module*")) {
        Import-Module -Name $module -Force
    }
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
    $context = Get-MgContext
    Write-Host "`nSuccessfully connected to Microsoft Graph tenant $($context.TenantId)." -ForegroundColor Green
}
catch {
    Write-Error $_.Exception.Message
    exit
}
#endregion app auth

#region scopes
$currentScopes = $context.Scopes
# Validate required permissions
$missingScopes = $requiredScopes | Where-Object { $_ -notin $currentScopes }
if ($missingScopes.Count -gt 0) {
    Write-Host 'WARNING: The following scope permissions are missing:' -ForegroundColor Red
    $missingScopes | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
    Write-Host "`nPlease ensure these permissions are granted to the app registration for full functionality." -ForegroundColor Yellow
    exit
}
Write-Host "`nAll required scope permissions are present." -ForegroundColor Green
#endregion scopes

#region script
do {

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
    $intuneDevices = Get-ManagedDevice -os Windows
    $intuneDevicesHash = @{}
    foreach ($intuneDevice in $intuneDevices) {
        $intuneDevicesHash[$intuneDevice.id] = $intuneDevice
    }
    Write-Host "Found $($intuneDevices.Count) Windows device objects and associated IDs from Microsoft Intune." -ForegroundColor Green
    Write-Host ''

    Write-Host 'Getting all Windows Autopilot devices...' -ForegroundColor Cyan
    $apDevices = Get-AutopilotDevice
    $autopilotDevices = @()
    foreach ($apDevice in $apDevices) {
        # Details of Entra ID device object
        $entraObject = $entraDevicesHash[$apDevice.azureAdDeviceId]
        # Details of Intune device object
        #$intuneObject = $intuneDevicesHash[$apDevice.managedDeviceId]

        $autopilotDevices += [PSCustomObject]@{
            'displayName'              = $entraObject.displayName
            'serialNumber'             = $apDevice.serialNumber
            'manufacturer'             = $apDevice.manufacturer
            'model'                    = $apDevice.model
            'enrolmentState'           = $apDevice.enrollmentState
            'enrolmentProfile'         = $entraObject.enrollmentProfileName
            'enrolmentType'            = $entraObject.enrollmentType
            'groupTag'                 = $apDevice.groupTag
            'purchaseOrder'            = $apDevice.purchaseOrderIdentifier
            'Id'                       = $apDevice.Id
            'userlessEnrollmentStatus' = $apDevice.userlessEnrollmentStatus
        }
    }
    $autopilotDevicesHash = @{}
    foreach ($autopilotDevice in $autopilotDevices) {
        $autopilotDevicesHash[$autopilotDevice.id] = $autopilotDevice
    }
    Write-Host "Found $($autopilotDevices.Count) Windows Autopilot Devices from Microsoft Intune." -ForegroundColor Green
    #endregion discovery

    #region choices
    $choice = ''
    $autopilotUpdateDevices = @()
    while ($autopilotUpdateDevices.Count -eq 0) {
        if ($whatIf) {
            Write-Host "`nWhatIf mode enabled, no changes will be made." -ForegroundColor Magenta
        }
        if ($createGroups) {
            Write-Host "`nDynamic Groups will be created based on Group Tags" -ForegroundColor Green
        }
        Write-Host "`nPlease Choose one of the Group Tag options below:" -ForegroundColor White
        Write-Host "`n (1) Update All Autopilot Devices Group Tags" -ForegroundColor Cyan
        Write-Host "`n (2) Update All Autopilot Devices with Empty Group Tags" -ForegroundColor Cyan
        Write-Host "`n (3) Update All Autopilot Devices with a specific Group Tag" -ForegroundColor Cyan
        Write-Host "`n (4) Update All selected Manufacturers of Autopilot Device Group Tags" -ForegroundColor Cyan
        Write-Host "`n (5) Update All selected Models of Autopilot Device Group Tags" -ForegroundColor Cyan
        Write-Host "`n (6) Update All Autopilot Devices with a specific Purchase Order" -ForegroundColor Cyan
        Write-Host "`n (7) Update a selection of Autopilot Devices Group Tags interactively" -ForegroundColor Cyan
        Write-Host "`n (8) Update Autopilot Devices Group Tags using exported data" -ForegroundColor Cyan
        Write-Host "`n (a) Unblock All Autopilot Devices" -ForegroundColor Magenta
        Write-Host "`n (b) Unblock All blocked Autopilot Devices" -ForegroundColor Magenta
        Write-Host "`n (c) Unblock All selected Manufacturers of Autopilot Device" -ForegroundColor Magenta
        Write-Host "`n (d) Unblock All selected Models of Autopilot Device" -ForegroundColor Magenta
        Write-Host "`n (X) EXIT SCRIPT`n" -ForegroundColor Red
        $choice = Read-Host -Prompt 'Please select an option from the provided list, then press enter'
        while ( $choice -notin @('1', '2', '3', '4', '5', '6', '7', '8', 'a', 'b', 'c', 'd', 'X')) {
            $choice = Read-Host -Prompt 'Please select an option from the provided list, then press enter'
        }
        if ($choice -eq 'X') {
            exit
        }
        if ($choice -eq '1' -or $choice -eq 'a') {
            #All AutoPilot Devices
            $autopilotUpdateDevices = $autopilotDevices
        }
        if ($choice -eq '2') {
            #All AutoPilot Devices with Empty Group Tags
            $autopilotUpdateDevices = $autopilotDevices | Where-Object { ($null -eq $_.groupTag) -or ($_.groupTag) -eq '' }
            if ($autopilotUpdateDevices.count -eq 0) {
                Start-Sleep -Seconds $rndWait
                Write-Host 'No Autopilot Devices with Empty Group Tags found.' -ForegroundColor Yellow
                Write-Host 'Please select another option.' -ForegroundColor Yellow
                Start-Sleep -Seconds $rndWait
            }
        }
        if ($choice -eq '3') {
            # GroupTag prompts
            $confirmGroupTags = 0
            while ($confirmGroupTags -ne 1) {
                while ($autopilotGroupTags.count -eq 0) {
                    $autopilotGroupTags = @($autopilotDevices | Select-Object -Property groupTag -Unique | Out-ConsoleGridView -Title 'Select GroupTags of Autopilot Devices to Update' -OutputMode Multiple)
                }
                Write-Host "`nThe following Group Tag(s) were selected:`n" -ForegroundColor Cyan
                $autopilotGroupTags.groupTag
                $confirmGroupTags = Read-YesNoChoice -Title 'Please confirm Group Tag(s) selection' -Message 'Are these the correct Group Tag(s) to update?' -DefaultOption 1
                if ($confirmGroupTags -eq 0) {
                    Write-Host "`nPlease re-select the Group Tags to update" -ForegroundColor Yellow
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
                    $autopilotManufacturers = @($autopilotDevices | Select-Object -Property manufacturer -Unique | Out-ConsoleGridView -Title 'Select Manufacturer of Autopilot Devices to Update' -OutputMode Multiple)
                }
                Write-Host "`nThe following Autopilot Device Manufacturer(s) were selected:`n" -ForegroundColor Cyan
                $autopilotManufacturers.manufacturer
                $confirmManufacturers = Read-YesNoChoice -Title 'Please confirm the Autopilot Device Manufacturer(s)' -Message 'Are these the correct Manufacturer(s) to update?' -DefaultOption 1
                if ($confirmManufacturers -eq 0) {
                    Write-Host "`nPlease re-select the Manufacturer(s) to update" -ForegroundColor Yellow
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
                    $autopilotModels = @($autopilotDevices | Select-Object -Property model -Unique | Out-ConsoleGridView -Title 'Select Models of Autopilot Devices to Update' -OutputMode Multiple)
                }
                Write-Host "`nThe following Autopilot Device Model(s) were selected:`n" -ForegroundColor Cyan
                $autopilotModels.model
                $confirmModels = Read-YesNoChoice -Title 'Please confirm the Autopilot Device Model(s)' -Message 'Are these the correct Model(s) to update?' -DefaultOption 1
                if ($confirmModels -eq 0) {
                    Write-Host "`nPlease re-select the Models to update" -ForegroundColor Yellow
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
                    $autopilotPOs = @($autopilotDevices | Select-Object -Property purchaseOrder -Unique | Out-ConsoleGridView -Title 'Select Purchase Order of Autopilot Devices to Update' -OutputMode Multiple)
                }
                Write-Host "`nThe following Autopilot Device Purchase Order(s) were selected:`n" -ForegroundColor Cyan
                $autopilotPOs.purchaseOrder
                $confirmPOs = Read-YesNoChoice -Title 'Please confirm Autopilot Device Purchase Order(s)' -Message 'Are these the correct Purchase Order(s) to update?' -DefaultOption 1
                if ($confirmPOs -eq 0) {
                    Write-Host "`nPlease re-select the Purchase Order(s) to update" -ForegroundColor Yellow
                    $autopilotPOs = $null
                }
                $autopilotUpdateDevices = $autopilotDevices | Where-Object { $_.purchaseOrder -in $autopilotPOs.purchaseOrder }
            }
        }
        if ($choice -eq '7') {
            while ($autopilotUpdateDevices.count -eq 0) {
                $autopilotUpdateDevices = @($autopilotDevices | Out-ConsoleGridView -Title 'Select Autopilot Devices to Update' -OutputMode Multiple)
            }
        }
        if ($choice -eq '8') {
            # Report
            $autopilotDevices | Export-Csv -Path '.\AutopilotDevices.csv' -NoTypeInformation -Force
            Write-Host "`nExported All Autopilot Device(s) to AutopilotDevices.csv" -ForegroundColor Cyan
            while ($autopilotUpdateDevices.count -eq 0 -or ($autopilotUpdateDevices.groupTag | Measure-Object -Maximum).Maximum.length -gt 512) {
                if (($autopilotUpdateDevices.groupTag | Measure-Object -Maximum).Maximum.length -gt 512) {
                    Write-Host "`nOne or more Group Tags are greater than 512 characters." -ForegroundColor Red
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
        if ($choice -eq 'b') {
            # Unblock All blocked Autopilot Devices
            $autopilotUpdateDevices = $autopilotDevices | Where-Object { $_.userlessEnrollmentStatus -ne 'allowed' }
            if ($autopilotUpdateDevices.count -eq 0) {
                Start-Sleep -Seconds $rndWait
                Write-Host 'No Autopilot Devices are currently blocked.' -ForegroundColor Yellow
                Write-Host 'Please select another option.' -ForegroundColor Yellow
                Start-Sleep -Seconds $rndWait
            }
        }
        if ($choice -eq 'c') {
            # Manufacturer prompts
            $confirmManufacturers = 0
            while ($confirmManufacturers -ne 1) {
                while ($autopilotManufacturers.count -eq 0) {
                    $autopilotManufacturers = @($autopilotDevices | Select-Object -Property manufacturer -Unique | Out-ConsoleGridView -Title 'Select Manufacturer of Autopilot Devices to unblock' -OutputMode Multiple)
                }
                Write-Host "`nThe following Autopilot Device Manufacturer(s) were selected:`n" -ForegroundColor Cyan
                $autopilotManufacturers.manufacturer
                $confirmManufacturers = Read-YesNoChoice -Title 'Please confirm the Autopilot Device Manufacturer(s)' -Message 'Are these the correct Manufacturer(s) to unblock?' -DefaultOption 1
                if ($confirmManufacturers -eq 0) {
                    Write-Host "`nPlease re-select the Manufacturer(s) to unblock" -ForegroundColor Yellow
                    $autopilotManufacturers = $null
                }
                $autopilotUpdateDevices = $autopilotDevices | Where-Object { $_.manufacturer -in $autopilotManufacturers.manufacturer }
            }
        }
        if ($choice -eq 'd') {
            # Model prompts
            $confirmModels = 0
            while ($confirmModels -ne 1) {
                while ($autopilotModels.count -eq 0) {
                    $autopilotModels = @($autopilotDevices | Select-Object -Property model -Unique | Out-ConsoleGridView -Title 'Select Models of Autopilot Devices to unblock' -OutputMode Multiple)
                }
                Write-Host "`nThe following Autopilot Device Model(s) were selected:`n" -ForegroundColor Cyan
                $autopilotModels.model
                $confirmModels = Read-YesNoChoice -Title 'Please confirm the Autopilot Device Model(s)' -Message 'Are these the correct Model(s) to unblock?' -DefaultOption 1
                if ($confirmModels -eq 0) {
                    Write-Host "`nPlease re-select the Models to unblock" -ForegroundColor Yellow
                    $autopilotModels = $null
                }
                $autopilotUpdateDevices = $autopilotDevices | Where-Object { $_.model -in $autopilotModels.model }
            }
        }
    }
    #endregion choices

    #region group tag prompt
    if ($choice -notin @('a', 'b', 'c', 'd')) {
        if ($choice -ne '8') {
            #group tags have a maximum of 512 characters
            $confirmGroupTag = 0
            while ($confirmGroupTag -ne 1) {
                Write-Host 'Press Enter to select an empty Group Tag value which will remove the Group Tag from the Autopilot Device(s).' -ForegroundColor Yellow
                Write-Host ''
                [string]$groupTagNew = Read-Host "Please enter the *NEW* group tag you wish to apply to the $($autopilotUpdateDevices.Count) Autopilot device(s)"
                while ($groupTagNew.length -gt 512) {
                    [string]$groupTagNew = Read-Host "Please enter the *NEW* group tag you wish to apply to the $($autopilotUpdateDevices.Count) Autopilot device(s) but with less than 512 characters"
                }
                Write-Host ''
                Write-Host 'The following Autopilot Device Group Tag was entered:' -ForegroundColor Cyan
                Write-Host ''
                $groupTagNew
                if ($groupTagNew -eq '' -or $null -eq $groupTagNew) {
                    Write-Host 'An empty Group Tag value will remove the Group Tag from the Autopilot Device(s).' -ForegroundColor red
                    Write-Host ''
                }
                $confirmGroupTag = Read-YesNoChoice -Title 'Please confirm the Autopilot Device Group Tag' -Message 'Is this the correct Group Tag to use?' -DefaultOption 1
                if ($confirmGroupTag -eq 0) {
                    Write-Host ''
                    Write-Host 'Please re-enter a *NEW* Group Tag' -ForegroundColor Yellow
                    Write-Host ''
                    $groupTagNew = $null
                }
            }
        }
    }
    #endregion group tag prompt

    #region Autopilot device update
    Write-Host "`nThe following $($autopilotUpdateDevices.Count) Autopilot device(s) are in scope to be updated:" -ForegroundColor Yellow
    $autopilotUpdateDevices | Format-Table -Property displayName, serialNumber, manufacturer, model, purchaseOrder, userlessEnrollmentStatus -AutoSize

    if ($whatIf) {
        Write-Host "`nWhatIf mode enabled, no changes will be made." -ForegroundColor Magenta
    }

    Write-Warning -Message "You are about to update $($autopilotUpdateDevices.Count) Autopilot device(s)." -WarningAction Inquire

    $progressCount = 0
    $progressTotal = $($autopilotUpdateDevices.Count)
    $progressActivity = 'Updating Autopilot Device(s) with '
    $Host.PrivateData.ProgressBackgroundColor = $Host.UI.RawUI.BackgroundColor
    $host.PrivateData.ProgressForegroundColor = 'green'
    Write-Progress -Activity $progressActivity -Status 'Starting' -PercentComplete 0

    foreach ($autopilotUpdateDevice in $autopilotUpdateDevices) {
        Start-Sleep -Seconds $rndWait
        if ($choice -eq '8') {
            $groupTagNew = $($autopilotUpdateDevice.groupTag)
        }

        #Write-Host "Updating Autopilot Group Tag with Serial Number: $($autopilotUpdateDevice.serialNumber) to '$groupTagNew'." -ForegroundColor Cyan
        $progressCount++
        $progressComplete = (($progressCount / $progressTotal) * 100)
        $progressStatus = "serial number: $($autopilotUpdateDevice.serialNumber)"
        Write-Progress -Activity $progressActivity -Status $progressStatus -PercentComplete $progressComplete
        if (!$whatIf) {
            if ($choice -notin @('a', 'b', 'c', 'd')) {
                Set-AutopilotDevice -id $autopilotUpdateDevice.id -groupTag $groupTagNew -Confirm:$false
            }
            else {
                Set-AutopilotDevice -id $autopilotUpdateDevice.id -unblock:$true -Confirm:$false
            }

        }
        #Write-Host "Updated Autopilot Group Tag with Serial Number: $($autopilotUpdateDevice.serialNumber) to '$groupTagNew'." -ForegroundColor Green
    }

    Write-Progress -Activity $progressActivity -Status 'Complete' -PercentComplete 100
    Write-Host "Successfully updated $($autopilotUpdateDevices.Count) Autopilot device(s)" -ForegroundColor Green
    #endregion Autopilot device update

    #region Group Creation
    if ($choice -notin @('a', 'b', 'c', 'd')) {
        if ($createGroups) {
            $groupTagsArray = @()
            if ($choice -eq '8') {
                foreach ($autopilotUpdateDevice in $autopilotUpdateDevices) {
                    $groupTagsArray += $($autopilotUpdateDevice.groupTag)
                }
            }
            else {
                $groupTagsArray += $groupTagNew
            }
            $groupTagsArray = $groupTagsArray | Select-Object -Unique
            $groupsArray = @()
            foreach ($groupTagArray in $groupTagsArray) {
                $groupRule = "(device.devicePhysicalIds -any _ -eq `\`"[OrderID]:$groupTagArray`\`")"
                $groupsArray += [pscustomobject]@{displayName = "$($groupPrefix + $groupTagArray)"; description = "All Autopilot Devices with Group Tag '$groupTagArray' created by AutopilotGroupTagger"; rule = "$groupRule" }
            }
            Write-Host "`nThe following $($groupsArray.Count) group(s) will be created:" -ForegroundColor Yellow
            $groupsArray | Select-Object -Property displayName, rule, description | Format-Table -AutoSize

            Write-Warning -Message "You are about to create $($groupsArray.Count) new group(s) in Microsoft Entra ID. Please confirm you want to continue." -WarningAction Inquire

            foreach ($group in $groupsArray) {
                Start-Sleep -Seconds $rndWait
                $groupName = $($group.displayName)
                if ($groupName.length -gt 120) {
                    #shrinking group name to less than 120 characters
                    $groupName = $groupName[0..120] -join ''
                }

                if (!(Get-MDMGroup -groupName $groupName)) {
                    Write-Host "`nCreating Group $groupName with rule $($group.rule)" -ForegroundColor Cyan
                    $groupJSON = @"
{
    "description": "$($group.description)",
    "displayName": "$groupName",
    "groupTypes": [
        "DynamicMembership"
    ],
    "mailEnabled": false,
    "mailNickname": "$groupName",
    "securityEnabled": true,
    "membershipRule": "$($group.rule)",
    "membershipRuleProcessingState": "On"
}
"@
                    if ($whatIf) {
                        Write-Host 'WhatIf mode enabled, no changes will be made.' -ForegroundColor Magenta
                        continue
                    }
                    else {
                        New-MDMGroup -JSON $groupJSON | Out-Null
                    }
                    Write-Host "Group $($group.displayName) created successfully." -ForegroundColor Green
                }
                else {
                    Write-Host "Group $($group.displayName) already exists, skipping creation." -ForegroundColor Yellow
                    continue
                }
            }
            Write-Host "Successfully created $($groupsArray.Count) new group(s) in Microsoft Entra ID." -ForegroundColor Green
        }
    }

    #endregion Group Creation

    $continueScript = Read-YesNoChoice -Title 'Continue AutopilotGroupTagger' -Message 'Do you want to update additional Autopilot device(s)?' -DefaultOption 0
    Clear-Host
}

until ($continueScript -eq '0')
#endregion script