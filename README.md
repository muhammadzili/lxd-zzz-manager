# ⚡ LXD Zzz Manager CLI

<p align="center">
  <img src="https://img.shields.io/badge/Language-Bash-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white" />
  <img src="https://img.shields.io/badge/Virtualization-LXD/LXC-E95420?style=for-the-badge&logo=linux-containers&logoColor=white" />
  <img src="https://img.shields.io/badge/License-MIT-007EC6?style=for-the-badge&logo=open-source-initiative&logoColor=white" />
  <img src="https://img.shields.io/badge/Version-1.0-FFD700?style=for-the-badge" />
</p>

---

## 🧭 Tentang Repositori

**LXD Zzz Manager** adalah tool **CLI (Command Line Interface)** berbasis **Bash Script** yang dirancang untuk mengotomatisasi manajemen VPS menggunakan teknologi **LXD/LXC** pada server Ubuntu atau Debian.

Script ini memungkinkan satu server **Dedicated / VPS besar (Host)** dipecah menjadi beberapa **VPS kecil (Container)** yang terisolasi, lengkap dengan:
- Limitasi resource (RAM, CPU, Disk)
- Akses SSH independen
- Port forwarding otomatis

---

## ⚙️ Masalah & Solusi

### ❌ Masalah
Manajemen container LXD secara manual cukup ribet:
- Menjalankan `lxd launch`
- Set RAM, CPU, Disk satu per satu
- Mapping port dengan iptables / proxy
- Edit konfigurasi SSH agar bisa login password

### ✅ Solusi
**LXD Zzz Manager** menyederhanakan semuanya **cukup 1 klik**:
- Pilih menu
- Masukkan data
- VPS langsung siap digunakan 🚀

---

## 🚀 Fitur Utama

- 🖥️ **Menu Interaktif**
- 📦 **Auto Install LXD**
- ⚡ **Resource Limiter**
- 🔒 **SSH Port Forwarding**
- 🛡️ **Auto Firewall (UFW)**
- 🔑 **Auto Fix SSH Login**
- 🐧 **Multi-OS Support**

---

## 🛠️ Prasyarat (Host System)

- OS: Ubuntu 20.04 / 22.04 LTS atau Debian 11  
- User: Root  
- Virtualization: LXD supported

---

## 📦 Cara Install & Penggunaan

```bash
wget https://raw.githubusercontent.com/muhammadzili/lxd-zzz-manager/main/lxd-zzz.sh
chmod +x lxd-zzz.sh
./lxd-zzz.sh
```

---

## 📜 Lisensi

MIT License
