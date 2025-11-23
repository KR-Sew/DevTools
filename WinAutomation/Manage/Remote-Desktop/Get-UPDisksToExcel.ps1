# Alternative method using Excel COM objects
Import-Module ActiveDirectory

$updFolderPath = "\\vezufs2\farmdpc$\"
$outputFile = "D:\Temp\UPD_User_Mapping.xlsx"

# Get all .vhdx files and process them
$results = @()
Get-ChildItem -Path $updFolderPath -Filter "UVHD-S-*.vhdx" | ForEach-Object {
    $fileName = $_.Name
    if ($fileName -match "^UVHD-S-(.+)\.vhdx$") {
        $sidString = $matches[1]
        
        try {
            $sid = New-Object System.Security.Principal.SecurityIdentifier("S-$sidString")
            $user = Get-ADUser -Filter {SID -eq $sid} -Properties DisplayName, UserPrincipalName -ErrorAction SilentlyContinue
            
            $results += [PSCustomObject]@{
                FileName = $fileName
                SID = $sid.Value
                Username = if ($user) { $user.SamAccountName } else { "Not Found" }
                DisplayName = if ($user) { $user.DisplayName } else { "Not Found" }
                UserPrincipalName = if ($user) { $user.UserPrincipalName } else { "Not Found" }
                Status = if ($user) { "Found" } else { "Not Found" }
            }
        }
        catch {
            $results += [PSCustomObject]@{
                FileName = $fileName
                SID = "S-$sidString"
                Username = "Invalid SID"
                DisplayName = "Invalid SID"
                UserPrincipalName = "Invalid SID"
                Status = "Invalid SID"
            }
        }
    }
}

# Create Excel application
$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false
$excel.DisplayAlerts = $false

# Create workbook
$workbook = $excel.Workbooks.Add()
$worksheet = $workbook.Worksheets.Item(1)
$worksheet.Name = "UPD Mapping"

# Add headers
$headers = @("FileName", "SID", "Username", "DisplayName", "UserPrincipalName", "Status")
for ($i = 0; $i -lt $headers.Count; $i++) {
    $worksheet.Cells.Item(1, $i + 1) = $headers[$i]
    $worksheet.Cells.Item(1, $i + 1).Font.Bold = $true
}

# Add data
$row = 2
foreach ($item in $results) {
    $worksheet.Cells.Item($row, 1) = $item.FileName
    $worksheet.Cells.Item($row, 2) = $item.SID
    $worksheet.Cells.Item($row, 3) = $item.Username
    $worksheet.Cells.Item($row, 4) = $item.DisplayName
    $worksheet.Cells.Item($row, 5) = $item.UserPrincipalName
    $worksheet.Cells.Item($row, 6) = $item.Status
    $row++
}

# Auto-fit columns
$worksheet.UsedRange.EntireColumn.AutoFit() | Out-Null

# Add filter
$worksheet.UsedRange.AutoFilter() | Out-Null

# Save and close
$workbook.SaveAs($outputFile)
$workbook.Close()
$excel.Quit()

# Clean up COM objects
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($worksheet) | Out-Null
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($workbook) | Out-Null
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null
[System.GC]::Collect()
[System.GC]::WaitForPendingFinalizers()

Write-Host "Results exported to: $outputFile" -ForegroundColor Green