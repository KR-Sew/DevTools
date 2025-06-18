# 📦 Automation installation for Windows Server with desktop or servercore mode

[![PowerShell](https://custom-icon-badges.demolab.com/badge/.-Microsoft-blue.svg?style=flat&logo=powershell-core-eyecatch32&logoColor=white)](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.5)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue?logo=powershell)](https://docs.microsoft.com/en-us/powershell/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

## ✅ Description of installation process

### Step 1: Prepare a Windows Server ISO for Automated Installation

✅ We will:

    Extend the PowerShell script to:

        Send an email via SMTP (e.g., using Gmail or internal SMTP)

        Send a message via a Telegram bot

    Configure your email and Telegram credentials

✉️ PART 1: Email Alerts Setup
🔧 You'll need:

    SMTP server (e.g., smtp.gmail.com, mail.vezu.com, etc.)

    Email username/password

    Recipient email address

🔐 Secure Credentials

Store them securely (you can use Windows Credential Manager later; for now, we use plain text for simplicity):

### Email config

```powershell
$smtpServer = "smtp.yourserver.com"
$smtpPort = 587
$emailFrom = "alerts@yourdomain.com"
$emailTo = "admin@yourdomain.com"
$emailUser = "alerts@yourdomain.com"
$emailPass = "your_password_here"

```

🤖 PART 2: Telegram Bot Setup
🔧 You'll need:

    A bot token from @BotFather

    Your Telegram user ID or a group ID

You can get your chat ID via this URL (after sending a message to your bot):

```bash
<https://api.telegram.org/bot><YOUR_BOT_TOKEN>/getUpdates
```

### Telegram config

```powershell
$telegramToken = "123456:ABCdefYourBotTokenHere"
$telegramChatId = "123456789" # user or group chat ID
```

🧪 FINAL SCRIPT (with alerts added)

### === Config ===

$eventLogName = "Security"
$eventIds = @(4728, 4729)
$lastRecordFile = "C:\Scripts\LastRecord.txt"
$logFile = "C:\Scripts\PrivGroupChangeLog.txt"

# Email config

$smtpServer = "smtp.yourserver.com"
$smtpPort = 587
$emailFrom = "alerts@yourdomain.com"
$emailTo = "<admin@yourdomain.com>"
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

🧰 Final Steps
✅ Save as:

C:\Scripts\Watch-PrivilegedGroupChanges.ps1
🕒 Set a Scheduled Task:

Run every 5 mins using Task Scheduler:

    Action: powershell.exe

    Arguments: -ExecutionPolicy Bypass -File "C:\Scripts\Watch-PrivilegedGroupChanges.ps1"

---

🔙 [back to Repos](../)
