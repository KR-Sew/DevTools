# Import modules
Import-Module ActiveDirectory
Import-Module ImportExcel

# Set paths
$updFolderPath = "\\vezufs2\farmdpc$\"
$outputFile = "D:\Temp\UPD_User2_Mapping.xlsx"

# Get UPD files and process them
$results = @()
Get-ChildItem -Path $updFolderPath -Filter "UVHD-S-*.vhdx" | ForEach-Object {
    $fileName = $_.Name
    if ($fileName -match "^UVHD-S-(.+)\.vhdx$") {
        $sidString = $matches[1]
        try {
            $sid = New-Object System.Security.Principal.SecurityIdentifier("S-$sidString")
            $user = Get-ADUser -Filter {SID -eq $sid} -Properties DisplayName, UserPrincipalName, Enabled -ErrorAction SilentlyContinue
            $results += [PSCustomObject]@{
                FileName = $fileName
                SID = $sid.Value
                Username = if ($user) { $user.SamAccountName } else { "Not Found" }
                DisplayName = if ($user) { $user.DisplayName } else { "Not Found" }
                UserPrincipalName = if ($user) { $user.UserPrincipalName } else { "Not Found" }
                AccountStatus = if ($user) { if ($user.Enabled) { "Enabled" } else { "Disabled" } } else { "N/A" }
                FileSize_GB = [math]::Round($_.Length / 1GB, 2)
                Status = if ($user) { "Found" } else { "User not found in AD" }
            }
        } catch {
            $results += [PSCustomObject]@{
                FileName = $fileName
                SID = "S-$sidString"
                Username = "Invalid SID"
                DisplayName = "Invalid SID"
                UserPrincipalName = "Invalid SID"
                AccountStatus = "N/A"
                FileSize_GB = [math]::Round($_.Length / 1GB, 2)
                Status = "Invalid SID format"
            }
        }
    } else {
        Write-Warning "File '$fileName' doesn't match expected naming pattern"
    }
}

# Export to Excel with conditional formatting
$excelParams = @{
    Path = $outputFile
    WorksheetName = "UPD Mapping"
    AutoSize = $true
    FreezeTopRow = $true
    BoldTopRow = $true
    AutoFilter = $true
    TableStyle = "Medium6"
    ConditionalText = @(
        # Format for found users
        @{ Range = "H:H"; Condition = 'Equal to "Found"'; ForegroundColor = "Green" },
        # Format for not found users
        @{ Range = "H:H"; Condition = 'Equal to "User not found in AD"'; ForegroundColor = "Orange" },
        # Format for invalid SIDs
        @{ Range = "H:H"; Condition = 'Equal to "Invalid SID format"'; ForegroundColor = "Red" },
        # Format for disabled accounts
        @{ Range = "F:F"; Condition = 'Equal to "Disabled"'; ForegroundColor = "Red" }
    )
}

$results | Export-Excel @excelParams

Write-Host "UPD mapping report exported to: $outputFile" -ForegroundColor Green