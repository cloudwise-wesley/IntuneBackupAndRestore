function Invoke-IntuneBackupGroupPolicyConfigurationAssignment {
    <#
    .SYNOPSIS
    Backup Intune Group Policy Configuration Assignments
    
    .DESCRIPTION
    Backup Intune Group Policy Configuration Assignments as JSON files per Group Policy Configuration Policy to the specified Path.
    
    .PARAMETER Path
    Path to store backup files
    
    .EXAMPLE
    Invoke-IntuneBackupGroupPolicyConfigurationAssignment -Path "C:\temp"
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
    if (-not (Test-Path "$Path\Administrative Templates\Assignments")) {
        $null = New-Item -Path "$Path\Administrative Templates\Assignments" -ItemType Directory
    }

    # Get all assignments from all policies
    $groupPolicyConfigurations = (Invoke-MgGraphRequest -Method GET -URI "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations" | Get-MgGraphDataWithPagination).value

    foreach ($groupPolicyConfiguration in $groupPolicyConfigurations) {
        $assignments = (Invoke-MgGraphRequest -Method GET -URI "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations/$($groupPolicyConfiguration.id)/assignments" | Get-MgGraphDataWithPagination).value
        
        if ($assignments) {
            $fileName = ($groupPolicyConfiguration.displayName).Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
            $assignments | ConvertTo-Json | Out-File -LiteralPath "$path\Administrative Templates\Assignments\$fileName.json"

            [PSCustomObject]@{
                "Action" = "Backup"
                "Type"   = "Administrative Template Assignments"
                "Name"   = $groupPolicyConfiguration.displayName
                "Path"   = "Administrative Templates\Assignments\$fileName.json"
            }
        }
    } 
}