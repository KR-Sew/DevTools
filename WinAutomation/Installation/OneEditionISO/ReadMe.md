# 📦 Thes folder contains scripts to create your only one Server edition ISO image

[![PowerShell](https://custom-icon-badges.demolab.com/badge/.-Microsoft-blue.svg?style=flat&logo=powershell-core-eyecatch32&logoColor=white)](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.5)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue?logo=powershell)](https://docs.microsoft.com/en-us/powershell/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

## ✅ Goal

Create a bootable Windows Server 2025 ISO containing only one Server Core edition (e.g., Datacenter Core) using DISM and oscdimg from the ADK.

## 🧱 Requirements

- Windows ADK installed (make sure to include Deployment Tools).
  If you don't have ADK you can use [`Install-WindowsADK.ps1`](./Install-WindowsADK.ps1) to download and install the Windows ADK and optionally `WinPE` add-on.
- Original Windows Server 2025 ISO.
- Exported WIM file (with only the desired Server Core edition).
- `oscdimg.exe` (from ADK path:
   `C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe`)

## 🪜 Step by Step instruction of creating process

### 1. Mount the original ISO

The ISO must include a complete set of Windows installation files, including:

- Boot files: `bootmgr`, `bootmgr.efi`, `efi\`, `boot\`
- Setup engine: `setup.exe`, `sources\boot.wim`
- Installation image: sources\install.wim (✅ you already have this)

✅ Minimum Files Required for a Bootable Windows ISO

Here’s what must be in the root of the ISO:

```scss
   [boot]                 ← contains boot sector files (etfsboot.com, etc.)
   [efi]                  ← for UEFI booting
   [sources]
       boot.wim           ← WinPE boot image (installer runs from this)
       install.wim        ← Your customized OS image (✅ you created this)
   bootmgr                ← Boot loader for BIOS
   bootmgr.efi            ← Boot loader for UEFI
   setup.exe              ← The Windows setup program
```

If you created an ISO with only `install.wim`, there’s no boot environment to load the installer — hence nothing happens when you boot the VM.

Let’s assume:

- Original ISO is `D:\`
- Working folder: `C:\WS2025_CoreISO`

```powershell
   mkdir C:\WS2025_CoreISO
   robocopy D:\ C:\WS2025_CoreISO /E
```

### 2. List available editions in your WIM

```powershell
   dism /Get-ImageInfo /ImageFile:"C:\ISO\Sources\install.wim"
```

### 2. Export only the desired Server Core edition

Let's say you want to extract Datacenter Core from index 4:

```powershell
   dism /Export-Image /SourceImageFile:"D:\sources\install.wim" /SourceIndex:4 /DestinationImageFile:"C:\WS2025_CoreISO\sources\install.wim" /Compress:max /CheckIntegrity
```

✅ This command creates a new install.wim with only one edition.

### 3. (Optional) Confirm image content

To double check:

```powershell
   dism /Get-ImageInfo /ImageFile:"C:\WS2025_CoreISO\sources\install.wim"
```

Make sure it lists only Datacenter Core or whatever edition you exported.

### 4. Create the bootable ISO

Run oscdimg to build the ISO.
These are required for UEFI booting.
You can also add UEFI boot support using -bootdata:

```powershell
   oscdimg.exe -u2 -udfver102 -bootdata:2#p0,e,bD:\tmp\ServerCore\boot\etfsboot.com#pEF,e,bD:\tmp\ServerCore\efi\microsoft\boot\efisys.bin -lWS2025_CORE D:\tmp\ServerCore D:\tmp\WS2025_CoreOnly.iso
```

Explanation of parameters:

- `-b`: Boot sector file (etfsboot.com)
- `-u2`: UDF file system
- `-h`: Include hidden files
- `-m`: Ignore max size limit (for large ISOs)
- `-l`: ISO volume label
- `C:\WS2025_CoreISO`: Source folder
- `C:\WS2025_DatacenterCore.iso`: Destination ISO

### ✅ Done

Now C:\WS2025_DatacenterCore.iso is a bootable ISO with only one Server Core edition, ready for:

- VM boot
- Bare metal deployment
- PXE boot (with WDS)

### 🔧 Automated scripts

1.📝[`Create-ServerIso-DualBoot.ps1`](./Create-ServerIso-DualBoot.ps1)

This version of script includes:

- Copying the full ISO content
- Replacing install.wim with your custom edition
- Building a bootable ISO that supports UEFI + BIOS
- Uses -bootdata with oscdimg for full compatibility

### 📌 Example Usage

```powershell
   .\Create-ServerISO-DualBoot.ps1 `
    -SourceISO "D:\ISO\Windows_Server_2025.iso" `
    -EditionIndex 4 `
    -OutputISO "C:\ISOs\WS2025_Core_DualBoot.iso"
```

### 🧩 Notes

- This ISO will now boot on any system, regardless of whether it's:

  - Legacy BIOS
  - UEFI
  - Secure Boot enabled
- Make sure that `efisys.bin` and `etfsboot.com` exist:
  - `etfsboot.com` → in `boot\`
  - `efisys.bin` → in `efi\microsoft\boot\`

You can always copy them from a mounted original ISO if they’re missing.

2 📝.[`Create-ServerIso-Interactive.ps1`](./Create-ServerIso-Interacitve.ps1)

This script lists all editions in install.wim and lets you choose one from a menu. Then it proceeds to build the dual-mode bootable ISO.

- Run the ADK installer script first to install tools.[`Install-WindowsADK.ps1`](./Install-WindowsADK.ps1)
- Then use the interactive ISO builder to create your Server Core-only image.

---

🔙 [back to Repos](../)
