# PowerShell script to extract SIDs from UPD disk filenames and get usernames from AD

# Import Active Directory module
Import-Module ActiveDirectory

# Set the path to your UPD disks folder
$updFolderPath = "\\vezufs2\farmdpc$\"

# Get all .vhdx files in the folder
$updFiles = Get-ChildItem -Path $updFolderPath -Filter "*.vhdx"

# Array to store results
$results = @()

foreach ($file in $updFiles) {
    # Extract SID from filename (format: UVHD-S-1-5-21-450286647-856145330-3256113641-8664.vhdx)
    $fileName = $file.Name
    
    # Remove the .vhdx extension and the "UVHD-S-" prefix
    if ($fileName -match "^UVHD-S-(.+)\.vhdx$") {
        $sidString = $matches[1]
        
        try {
            # Create SID object
            $sid = New-Object System.Security.Principal.SecurityIdentifier("S-$sidString")
            
            # Try to get user from AD
            $user = Get-ADUser -Filter {SID -eq $sid} -Properties DisplayName, UserPrincipalName -ErrorAction SilentlyContinue
            
            if ($user) {
                $result = [PSCustomObject]@{
                    FileName = $file.Name
                    SID = $sid.Value
                    Username = $user.SamAccountName
                    DisplayName = $user.DisplayName
                    UserPrincipalName = $user.UserPrincipalName
                    Status = "Found"
                }
            } else {
                $result = [PSCustomObject]@{
                    FileName = $file.Name
                    SID = $sid.Value
                    Username = "Not Found"
                    DisplayName = "Not Found"
                    UserPrincipalName = "Not Found"
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
                Status = "Invalid SID format"
            }
        }
        
        $results += $result
    } else {
        Write-Warning "File '$fileName' doesn't match expected naming pattern"
    }
}

# Display results
$results | Format-Table -AutoSize

# Optionally export to CSV
$results | Export-Csv -Path "d:\Temp\UPD_User_Mapping.csv" -NoTypeInformation

Write-Host "Results have been exported to UPD_User_Mapping.csv" -ForegroundColor Green