# ⚡ LXD Zzz Manager CLI

<p align="center">
  <img src="https://img.shields.io/badge/Language-Bash-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white" />
  <img src="https://img.shields.io/badge/Virtualization-LXD/LXC-E95420?style=for-the-badge&logo=linux-containers&logoColor=white" />
  <img src="https://img.shields.io/badge/License-MIT-007EC6?style=for-the-badge&logo=open-source-initiative&logoColor=white" />
  <img src="https://img.shields.io/badge/Version-1.2-FFD700?style=for-the-badge" />
</p>

---

## 🧭 About the Repository

**LXD Zzz Manager** is a **Bash Script**-based **CLI (Command Line Interface)** tool designed to automate VPS management using **LXD/LXC** technology on Ubuntu or Debian servers.

This script allows a single **Dedicated / Large VPS (Host)** to be split into several isolated **Small VPS (Containers)**, complete with:
- Resource limits (RAM, CPU, Disk)
- Independent SSH access
- Automatic port forwarding

---

## ⚙️ Problems & Solutions

### ❌ Problem
Manually managing LXD containers is quite complicated:
- Running `lxd launch`
- Setting RAM, CPU, and Disk one by one
- Port mapping with iptables / proxy
- Editing SSH configuration to allow password login

### ✅ Solution
**LXD Zzz Manager** simplifies everything with just **one click**:
- Select a menu
- Enter the data
- The VPS is ready to use immediately 🚀

---

## 🚀 Key Features

- 🖥️ **Interactive Menu**
- 📦 **Auto Install LXD**
- ⚡ **Resource Limiter**
- 🔒 **SSH Port Forwarding**

---

## 🛠️ Prerequisites (Host System)

- OS: Ubuntu 20.04 / 22.04 LTS or Debian 11  
- User: Root  
- Virtualization: LXD supported

---

## 📦 Installation & Usage Guide

```bash
wget https://raw.githubusercontent.com/muhammadzili/lxd-zzz-manager/main/lxd-zzz.sh
chmod +x lxd-zzz.sh
./lxd-zzz.sh
```

---

## 📜 License

MIT License
