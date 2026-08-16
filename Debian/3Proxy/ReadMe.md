# Installing and managing **3Proxy** server

[![Debian](https://img.shields.io/badge/Debian-607078?style=flat&logo=debian&logoColor=white&logoSize=auto&labelColor=a81d33)](https://www.debian.org/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-607078?style=flat&logo=ubuntu&logoColor=white&logoSize=auto&labelColor=e95420)](https://ubuntu.com/download)
[![WSL](https://img.shields.io/badge/WSL-Microsoft-blue?style=flat&logo=linux&logoColor=white&logoSize=auto&labelColor=4E9A06)](https://learn.microsoft.com/en-us/windows/wsl/about)
[![Bash](https://img.shields.io/badge/GNU%20Bash-4EAA25?style=flat&logo=gnubash&logoColor=white&logoSize=auto&labelColor=black)](https://www.gnu.org/software/bash/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)
[![Database Icon by icons8.com](https://img.shields.io/badge/Database%20Icon%20by%20icon8.com-54f2f2.svg?logo=vsc&logoColor=white)](https://icons8.com)

## Description

- [**3proxy.cfg**](./3proxy.cfg)
  - Common configuration file for forward proxy server
- [**install_3proxy.sh**](./install_3proxy.sh)
  - Automatic installation script, that install **3proxy** as a service in: <p>
    [![Debian](https://img.shields.io/badge/Debian-607078?style=flat&logo=debian&logoColor=white&logoSize=auto&labelColor=a81d33)](https://www.debian.org/)
    [![Ubuntu](https://img.shields.io/badge/Ubuntu-607078?style=flat&logo=ubuntu&logoColor=white&logoSize=auto&labelColor=e95420)](https://ubuntu.com/download)</p>
  - to run [`this`](./install_3proxy.sh) script

    ```bash
       chmod +x install-3proxy.sh
       sudo ./install-3proxy.sh
    ```

    the generated config can be found here:

    ```bash
      /usr/local/3proxy/conf/3proxy.cfg
    ```

- [**update_3proxy.sh**](./update_3proxy.sh)
  - Update script for existed **3proxy** service. It checks a new version on `GitHub`,<p> create  a backup and update.</p>
  - how to use [`this`](./update_3proxy.sh) script
    - If you use `LXC` or `LXD` conatiner that's more convenient to use it :

    ```bash
      sudo mkdir -p /usr/local/sbin
      sudo cp update-3proxy.sh /usr/local/sbin/update-3proxy
      sudo chmod 755 /usr/local/sbin/update-3proxy
      sudo update-3proxy
    ```  

---

🔙 [back to Repos](https://github.com/KR-Sew?tab=repositories)
