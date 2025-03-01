function Invoke-IntuneRestoreConfigurationPolicyAssignment {
    <#
    .SYNOPSIS
    Restore Intune Configuration Policy Assignments
    
    .DESCRIPTION
    Restore Intune Configuration Policy Assignments from JSON files per Configuration Policy from the specified Path.
    
    .PARAMETER Path
    Root path where backup files are located, created with the Invoke-IntuneBackupConfigurationPolicyAssignment function

    .PARAMETER RestoreById
    If RestoreById is set to true, assignments will be restored to Intune Device Management Scripts that match the id.

    If RestoreById is set to false, assignments will be restored to Intune Device Management Scripts that match the file name.
    This is necessary if the Device Management Script was restored from backup, because then a new Device Management Script is created with a new unique ID.
    
    .EXAMPLE
    Invoke-IntuneBackupConfigurationPolicyAssignment -Path "C:\temp" -RestoreById $true
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [bool]$RestoreById = $false,

        [Parameter(Mandatory = $false)]
        [ValidateSet("v1.0", "Beta")]
        [string]$ApiVersion = "Beta"
    )

    # # Set the Microsoft Graph API endpoint
    # if (-not ((Get-MSGraphEnvironment).SchemaVersion -eq $apiVersion)) {
    #     Update-MSGraphEnvironment -SchemaVersion $apiVersion -Quiet
        Connect-MgGraph
    # }

    # Get all policies with assignments
    $configurationPolicies = Get-ChildItem -Path "$Path\Settings Catalog\Assignments"
    foreach ($configurationPolicy in $configurationPolicies) {
        $configurationPolicyAssignments = Get-Content -LiteralPath $configurationPolicy.FullName | ConvertFrom-Json
        $configurationPolicyId = ($configurationPolicyAssignments[0]).id.Split("_")[0]

        # Create the base requestBody
        $requestBody = @{
            assignments = @()
        }
        
        # Add assignments to restore to the request body
        foreach ($configurationPolicyAssignment in $configurationPolicyAssignments) {
            $requestBody.assignments += @{
                "target" = $configurationPolicyAssignment.target
            }
        }

        # Convert the PowerShell object to JSON
        $requestBody = $requestBody | ConvertTo-Json -Depth 100

        # Get the Configuration Policy we are restoring the assignments for
        try {
            if ($restoreById) {
                $configurationPolicyObject = (Invoke-MgGraphRequest -Method GET -URI "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies/$configurationPolicyId").value
            }
            else {
                $configurationPolicyObject = (Invoke-MgGraphRequest -Method GET -URI "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies" | Get-MgGraphDataWithPagination).value | Where-Object name -eq "$($configurationPolicy.BaseName)"
                if (-not ($configurationPolicyObject)) {
                    Write-Verbose "Error retrieving Intune Session Catalog for $($configurationPolicy.FullName). Skipping assignment restore" -Verbose
                    continue
                }
            }
        }
        catch {
            Write-Verbose "Error retrieving Intune Session Catalog for $($configurationPolicy.FullName). Skipping assignment restore" -Verbose
            Write-Error $_ -ErrorAction Continue
            continue
        }
 
        # Restore the assignments
        try {
            $null = Invoke-MgGraphRequest -Method POST -Body $requestBody.toString() -URI "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies/$($configurationPolicyObject.id)/assign" -ErrorAction Stop
            [PSCustomObject]@{
                "Action" = "Restore"
                "Type"   = "Settings Catalog Assignments"
                "Name"   = $configurationPolicyObject.name
                "Path"   = "Settings Catalog\Assignments\$($configurationPolicy.Name)"
            }
        }
        catch {
            Write-Verbose "$($configurationPolicyObject.name) - Failed to restore Settings Catalog Assignment(s)" -Verbose
            Write-Error $_ -ErrorAction Continue
        }
    }
}