# === Config ===

$eventLogName = "Security"
$eventIds = @(4728, 4729)
$lastRecordFile = "C:\Scripts\LastRecord.txt"
$logFile = "C:\Scripts\PrivGroupChangeLog.txt"

# Email config
$smtpServer = "smtp.yourserver.com"
$smtpPort = 587
$emailFrom = "alerts@yourdomain.com"
$emailTo = "admin@yourdomain.com"
$emailUser = "alerts@yourdomain.com"
$emailPass = "your_password"

# Telegram config
$telegramToken = "123456:ABCdefYourBotTokenHere"
$telegramChatId = "123456789"

# === Script Start ===

if (!(Test-Path $lastRecordFile)) { Set-Content -Path $lastRecordFile -Value 0 }
$lastRecordId = Get-Content $lastRecordFile | ForEach-Object { [int]$_ }

$events = Get-WinEvent -FilterHashtable @{LogName=$eventLogName; Id=$eventIds; StartTime=(Get-Date).AddMinutes(-5) } |
  Where-Object { $_.RecordId -gt $lastRecordId } |
  Sort-Object RecordId

foreach ($event in $events) {
    [xml]$eventXml = $event.ToXml()
    $data = $eventXml.Event.EventData.Data

    $targetUser = $data[0]."#text"
    $groupName = $data[1]."#text"
    $callerUser = $data[4]."#text"
    $callerDomain = $data[3]."#text"
    $time = $event.TimeCreated
    $recordId = $event.RecordId

    $action = switch ($event.Id) {
        4728 { "added to" }
        4729 { "removed from" }
    }

    $msg = "[{0}] {1}\{2} {3} '{4}' group (target user: {5}) [EventID: {6}, RecordID: {7}]" -f `
        $time, $callerDomain, $callerUser, $action, $groupName, $targetUser, $event.Id, $recordId

    Write-Output $msg
    Add-Content -Path $logFile -Value $msg
    Set-Content -Path $lastRecordFile -Value $recordId

    # === Send Email ===
    try {
        Send-MailMessage -From $emailFrom -To $emailTo -Subject "Group Change Alert: $groupName" `
            -Body $msg -SmtpServer $smtpServer -Port $smtpPort `
            -UseSsl -Credential (New-Object PSCredential($emailUser, (ConvertTo-SecureString $emailPass -AsPlainText -Force)))
    } catch {
        Write-Warning "Email failed: $_"
    }

    # === Send Telegram Message ===
    try {
        $telegramUrl = "https://api.telegram.org/bot$telegramToken/sendMessage"
        $body = @{
            chat_id = $telegramChatId
            text    = $msg
            parse_mode = 'Markdown'
        }
        Invoke-RestMethod -Uri $telegramUrl -Method Post -Body $body
    } catch {
        Write-Warning "Telegram failed: $_"
    }
}
