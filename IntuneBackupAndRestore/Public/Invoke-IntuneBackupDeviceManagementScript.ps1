function Invoke-IntuneBackupDeviceManagementScript {
    <#
    .SYNOPSIS
    Backup Intune Device Management Scripts
    
    .DESCRIPTION
    Backup Intune Device Management Scripts as JSON files per Device Management Script to the specified Path.
    
    .PARAMETER Path
    Path to store backup files
    
    .EXAMPLE
    Invoke-IntuneBackupDeviceManagementScript -Path "C:\temp"
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [ValidateSet("v1.0", "Beta")]
        [string]$ApiVersion = "Beta"
    )

    # # Set the Microsoft Graph API endpoint
    # if (-not ((Get-MSGraphEnvironment).SchemaVersion -eq $apiVersion)) {
    #     Update-MSGraphEnvironment -SchemaVersion $apiVersion -Quiet
        Connect-MgGraph
    # }

    # Create folder if not exists
    if (-not (Test-Path "$Path\Device Management Scripts\Script Content")) {
        $null = New-Item -Path "$Path\Device Management Scripts\Script Content" -ItemType Directory
    }

    # Get all device management scripts
    $deviceManagementScripts = (Invoke-MgGraphRequest -Method GET -URI "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts" | Get-MgGraphDataWithPagination).value

    foreach ($deviceManagementScript in $deviceManagementScripts) {
        # ScriptContent returns null, so we have to query Microsoft Graph for each script
        $deviceManagementScriptObject = Invoke-MgGraphRequest -Method GET -URI "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts/$($deviceManagementScript.Id)"
        $deviceManagementScriptFileName = ($deviceManagementScriptObject.displayName).Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
        $deviceManagementScriptObject | ConvertTo-Json | Out-File -LiteralPath "$path\Device Management Scripts\$deviceManagementScriptFileName.json"

        $deviceManagementScriptContent = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($deviceManagementScriptObject.scriptContent))
        $deviceManagementScriptContent | Out-File -LiteralPath "$path\Device Management Scripts\Script Content\$deviceManagementScriptFileName.ps1"

        [PSCustomObject]@{
            "Action" = "Backup"
            "Type"   = "Device Management Script"
            "Name"   = $deviceManagementScript.displayName
            "Path"   = "Device Management Scripts\$deviceManagementScriptFileName.json"
        }
    }
} 