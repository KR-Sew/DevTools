# PowerShell script to extract SIDs from UPD disk filenames, get usernames from AD, and export to Excel

# Import required modules
Import-Module ActiveDirectory
Import-Module ImportExcel

# Set the path to your UPD disks folder
$updFolderPath = "\\vezufs2\farmdpc$\"

# Set output Excel file path
$outputFile = "D:\Temp\UPD_UserAndSize_Mapping.xlsx"

# Get all .vhdx files in the folder
$updFiles = Get-ChildItem -Path $updFolderPath -Filter "*.vhdx"

# Array to store results
$results = @()

foreach ($file in $updFiles) {
    # Extract SID from filename
    $fileName = $file.Name
    
    if ($fileName -match "^UVHD-S-(.+)\.vhdx$") {
        $sidString = $matches[1]
        
        try {
            # Create SID object
            $sid = New-Object System.Security.Principal.SecurityIdentifier("S-$sidString")
            
            # Try to get user from AD
            $user = Get-ADUser -Filter {SID -eq $sid} -Properties DisplayName, UserPrincipalName, Enabled, LastLogonDate -ErrorAction SilentlyContinue
            
            if ($user) {
                $result = [PSCustomObject]@{
                    FileName = $file.Name
                    SID = $sid.Value
                    Username = $user.SamAccountName
                    DisplayName = $user.DisplayName
                    UserPrincipalName = $user.UserPrincipalName
                    AccountEnabled = $user.Enabled
                    LastLogonDate = $user.LastLogonDate
                    FileSize_GB = [math]::Round($file.Length / 1GB, 2)
                    Status = "Found"
                }
            } else {
                $result = [PSCustomObject]@{
                    FileName = $file.Name
                    SID = $sid.Value
                    Username = "Not Found"
                    DisplayName = "Not Found"
                    UserPrincipalName = "Not Found"
                    AccountEnabled = "N/A"
                    LastLogonDate = "N/A"
                    FileSize_GB = [math]::Round($file.Length / 1GB, 2)
                    Status = "User not found in AD"
                }
            }
        }
        catch {
            $result = [PSCustomObject]@{
                FileName = $file.Name
                SID = "S-$sidString"
                Username = "Invalid SID"
                DisplayName = "Invalid SID"
                UserPrincipalName = "Invalid SID"
                AccountEnabled = "N/A"
                LastLogonDate = "N/A"
                FileSize_GB = [math]::Round($file.Length / 1GB, 2)
                Status = "Invalid SID format"
            }
        }
        
        $results += $result
    } else {
        Write-Warning "File '$fileName' doesn't match expected naming pattern"
    }
}

# Export to Excel with formatting
$results | Export-Excel -Path $outputFile -WorksheetName "UPD Mapping" -AutoSize -FreezeTopRow -BoldTopRow -AutoFilter -TableName "UPDTable" -TableStyle "Medium6"

# Additional formatting options (optional)
$excelParams = @{
    Path = $outputFile
    WorksheetName = "UPD Mapping"
    AutoSize = $true
    FreezeTopRow = $true
    BoldTopRow = $true
    AutoFilter = $true
    TableStyle = "Medium6"
    ConditionalText = @(
        @{Range = "I:I"; Condition = 'Equal to "Found"'; ForegroundColor = "Green" },
        @{Range = "I:I"; Condition = 'Equal to "User not found in AD"'; ForegroundColor = "Orange" },
        @{Range = "I:I"; Condition = 'Equal to "Invalid SID format"'; ForegroundColor = "Red" }
    )
}

$results | Export-Excel @excelParams

Write-Host "Results have been exported to: $outputFile" -ForegroundColor Green
Write-Host "Total UPD disks processed: $($results.Count)" -ForegroundColor Cyan