# 📦 Automation installation for Windows Server with desktop or servercore mode

[![PowerShell](https://custom-icon-badges.demolab.com/badge/.-Microsoft-blue.svg?style=flat&logo=powershell-core-eyecatch32&logoColor=white)](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.5)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue?logo=powershell)](https://docs.microsoft.com/en-us/powershell/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

## ✅ Description of installation process

### Step 1: Prepare a Windows Server ISO for Automated Installation

To create an automated installation, you need to modify the Windows Server ISO and include an unattended answer file.

 1. ⚙️ Download Windows Server ISO

    Download the latest Windows Server ISO (Evaluation Edition) from Microsoft [Evaluation Center](https://www.microsoft.com/en-us/evalcenter/).

    Mount the ISO and copy its contents to a local folder, e.g., C:\WinServerISO.

 2. ⚙️ Add an Unattended Answer File
    - for installing Windows Server with `Desktop` feature add `autunattended.xml` from this [WinServer-Desktop/autounattend.xml)](./WinServer-Desktop/autounattend.xml)
    - for installing Windows Server in `Servercore` mode add `autounattended.xml` from this [WinServer-Core/autounattended.xml](./WinServer-Core/autounattended.xml)

    Each of these files installs Windows Server Standard without user interaction
 3. ⚙️Integrate the Unattended File into the ISO

    Place the `autounattend.xml` file in the root of your installation media (USB or ISO).

    Use the following command to create a new bootable ISO:

```powershell
oscdimg -m -o -u2 -bootdata:2#p0,e,bC:\WinServerISO\boot\etfsboot.com#pEF,e,bC:\WinServerISO\efi\microsoft\boot\efisys.bin C:\WinServerISO C:\WinServer_Auto.iso
```

 Now, your ISO will install Windows Server automatically with minimal input.

#### Step 4: Deployment Instructions

1. Copy `convert_to_standard.ps1` to your installation media (C:\) from here:
    - for installation with Deskto features [WinServer-Desktop/convert_to_std.ps1](./WinServer-Desktop/convert_to_std.ps1)
    - for installation in Servercore mode [WinServer-Core/convert_to_standard.ps1](./WinServer-Core/convert_to_standard.ps1)

   The system will boot, install Windows Server Core, and log in automatically.

   The PowerShell script will run and convert the `Evaluation` Edition to `Standard`   Edition.
  
2. The system will reboot to apply changes.

3. Final Outcome
    - Windows Server Core installs without GUI.
    - Automated conversion to Standard Edition happens right after installation.
    - The system is fully configured and ready to use without manual intervention.

---

🔙 [back to Repos](../)
