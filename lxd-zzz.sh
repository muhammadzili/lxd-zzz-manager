#!/bin/bash

# ==========================================
#   LXD Zzz VPS MANAGER v1.0
#   Copyright (c) Muhammad Zili
#   Automated LXD Container Creator
# ==========================================

# Warna biar ganteng
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# --- FUNGSI LOADING ANIMATION ---
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    echo -n " "
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# --- FUNGSI CEK & INSTALL LXD ---
function check_lxd_status() {
    echo -e "${BLUE}[INFO] Mengecek status LXD...${NC}"
    
    # 1. Cek apakah LXD terinstall
    if ! command -v lxd &> /dev/null; then
        echo -e "${YELLOW}[!] LXD tidak ditemukan. Sedang menginstall LXD (Snap)...${NC}"
        apt-get update > /dev/null 2>&1
        snap install lxd
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}[OK] LXD berhasil diinstall.${NC}"
        else
            echo -e "${RED}[FAIL] Gagal menginstall LXD. Cek koneksi internet.${NC}"
            exit 1
        fi
    else
        echo -e "${GREEN}[OK] LXD sudah terinstall.${NC}"
    fi

    # 2. Cek apakah LXD sudah di-init (Siap pakai)
    # Kita cek dengan mencoba list container. Jika error socket/refused, berarti belum init/running.
    if ! lxc list &> /dev/null; then
        echo -e "\n${YELLOW}[!] LXD belum diinisialisasi (Init).${NC}"
        echo -e "${CYAN}--- PANDUAN LXD INIT ---${NC}"
        echo -e "Script akan menjalankan 'lxd init' sekarang."
        echo -e "Jika bingung, tekan ${GREEN}ENTER${NC} terus untuk memilih opsi default (Aman)."
        echo -e "Penting: Saat ditanya 'Create a new zfs pool?', pilih yes (default)."
        echo -e "${CYAN}------------------------${NC}"
        read -p "Tekan Enter untuk memulai lxd init..."
        
        # Jalankan lxd init secara interaktif agar user bisa setting storage
        lxd init
        
        echo -e "\n${GREEN}[OK] Inisialisasi selesai.${NC}"
    fi
}

function show_header() {
    clear
    echo -e "${CYAN}=================================================${NC}"
    echo -e "${YELLOW}           LXD Zzz - VPS MANAGER v1.0            ${NC}"
    echo -e "${CYAN}       Created by Muhammad Zili (LXD Zzz)        ${NC}"
    echo -e "${CYAN}=================================================${NC}"
    echo ""
}

function buat_vps() {
    show_header
    echo -e "${GREEN}[ MENU: BUAT VPS BARU ]${NC}"
    
    # 1. Input Nama Hostname
    echo -e "${GREEN}[+] Masukkan Nama VPS (Hostname):${NC}"
    read -p ">> " VPS_NAME

    # Cek apakah nama sudah ada
    if lxc list | grep -q "$VPS_NAME"; then
        echo -e "${RED}[!] Error: VPS dengan nama $VPS_NAME sudah ada!${NC}"
        read -p "Tekan Enter untuk kembali..."
        main_menu
        return
    fi

    # 2. Input Port SSH Custom
    echo -e "\n${GREEN}[+] Masukkan Port SSH Custom (Contoh: 1248, 2023):${NC}"
    read -p ">> " SSH_PORT

    # 3. Pilihan OS
    echo -e "\n${GREEN}[+] Pilih Operating System (OS):${NC}"
    echo -e "${BLUE}1.${NC} Ubuntu 22.04 LTS (Recommended)"
    echo -e "${BLUE}2.${NC} Ubuntu 20.04 LTS"
    echo -e "${BLUE}3.${NC} Ubuntu 24.04 LTS (New)"
    echo -e "${BLUE}4.${NC} Debian 11 (Bullseye)"
    read -p "Pilih OS [1-4]: " OS_CHOICE

    case $OS_CHOICE in
        1) IMAGE="ubuntu:22.04" ;;
        2) IMAGE="ubuntu:20.04" ;;
        3) IMAGE="ubuntu:24.04" ;;
        4) IMAGE="images:debian/11" ;;
        *) IMAGE="ubuntu:22.04"; echo "Pilihan salah, default ke Ubuntu 22.04" ;;
    esac

    # 4. Pilihan Paket Resource
    echo -e "\n${GREEN}[+] Pilih Paket Spesifikasi VPS:${NC}"
    echo -e "${BLUE}1.${NC} Kecil    (RAM: 1GB,  Disk: 5GB,  CPU: 1 Core)"
    echo -e "${BLUE}2.${NC} Menengah (RAM: 3GB,  Disk: 20GB, CPU: 2 Core)"
    echo -e "${BLUE}3.${NC} Besar    (RAM: 5GB,  Disk: 40GB, CPU: 3 Core)"
    echo -e "${BLUE}4.${NC} Custom   (Isi sendiri)"
    echo ""
    read -p "Pilih Paket [1-4]: " PAKET

    case $PAKET in
        1) RAM="1GB"; DISK="5GB"; CPU="1" ;;
        2) RAM="3GB"; DISK="20GB"; CPU="2" ;;
        3) RAM="5GB"; DISK="40GB"; CPU="3" ;;
        4)
            read -p "Masukkan Limit RAM (cth: 2GB): " RAM
            read -p "Masukkan Limit Disk (cth: 15GB): " DISK
            read -p "Masukkan Limit CPU (cth: 2): " CPU
            ;;
        *)
            echo -e "${RED}[!] Pilihan tidak valid!${NC}"
            exit 1
            ;;
    esac

    echo -e "\n${YELLOW}>>> Sedang menyiapkan VPS: $VPS_NAME ($IMAGE)...${NC}"
    echo -e "    Spek: RAM $RAM | Disk $DISK | CPU $CPU | Port $SSH_PORT"

    # --- EKSEKUSI DENGAN LOADING ---
    echo -n "Installing System... "
    
    # Jalankan di background
    lxc launch "$IMAGE" "$VPS_NAME" > /dev/null 2>&1 &
    PID=$!
    # Tampilkan loading spinner
    spinner $PID
    wait $PID
    
    # Cek hasil
    if lxc list | grep -q "$VPS_NAME"; then
        echo -e "${GREEN}[DONE]${NC}"
    else
        echo -e "${RED}[FAIL]${NC}"
        echo -e "${RED}[!] Gagal membuat container. Cek koneksi atau storage pool.${NC}"
        read -p "Tekan Enter..."
        return
    fi

    echo -e "${BLUE}[INFO] Menunggu startup system (Booting)...${NC}"
    sleep 5 

    # Limit Resource
    lxc config set "$VPS_NAME" limits.memory "$RAM"
    lxc config set "$VPS_NAME" limits.cpu "$CPU"
    lxc config device override "$VPS_NAME" root size="$DISK" 2>/dev/null || lxc config device add "$VPS_NAME" root disk path=/ pool=default size="$DISK"

    # Port Forwarding SSH
    lxc config device add "$VPS_NAME" ssh-proxy proxy listen=tcp:0.0.0.0:"$SSH_PORT" connect=tcp:127.0.0.1:22 bind=host

    # Firewall
    ufw allow "$SSH_PORT"/tcp > /dev/null

    # Config SSH Fix
    echo -e "${BLUE}[INFO] Melakukan patching Config SSH & Security...${NC}"
    # Hapus cloud-init config yg ganggu
    lxc exec "$VPS_NAME" -- rm -f /etc/ssh/sshd_config.d/50-cloud-init.conf
    lxc exec "$VPS_NAME" -- rm -f /etc/ssh/sshd_config.d/60-cloudimg-settings.conf
    
    # Force settings di sshd_config
    lxc exec "$VPS_NAME" -- sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
    lxc exec "$VPS_NAME" -- sed -i 's/PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
    lxc exec "$VPS_NAME" -- sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
    lxc exec "$VPS_NAME" -- sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
    
    # Restart SSH
    lxc exec "$VPS_NAME" -- systemctl restart ssh

    # Set Password
    echo -e "\n${YELLOW}===============================================${NC}"
    echo -e "${YELLOW}   SILAKAN SET PASSWORD UNTUK VPS INI SEKARANG  ${NC}"
    echo -e "${YELLOW}===============================================${NC}"
    lxc exec "$VPS_NAME" -- passwd root

    # Summary
    IP_PUBLIC=$(curl -s ifconfig.me)
    echo -e "\n${CYAN}=================================================${NC}"
    echo -e "${GREEN}   VPS BERHASIL DIBUAT (LXD Zzz Manager v1.0)    ${NC}"
    echo -e "${CYAN}=================================================${NC}"
    echo -e "Nama VPS    : $VPS_NAME"
    echo -e "OS          : $IMAGE"
    echo -e "IP Address  : $IP_PUBLIC"
    echo -e "Port SSH    : $SSH_PORT"
    echo -e "User        : root"
    echo -e "Resource    : $RAM RAM / $CPU CPU / $DISK Disk"
    echo -e "${CYAN}=================================================${NC}"
    echo -e "Cara Login:"
    echo -e "${YELLOW}ssh root@$IP_PUBLIC -p $SSH_PORT${NC}"
    echo -e "${CYAN}=================================================${NC}"
    read -p "Tekan Enter untuk kembali ke menu..."
    main_menu
}

function tambah_port() {
    show_header
    echo -e "${GREEN}[ MENU: TAMBAH PORT KE VPS EXISTING ]${NC}"
    
    # List VPS aktif
    echo -e "${BLUE}Daftar VPS Aktif:${NC}"
    lxc list -c n,s | grep RUNNING | awk '{print $2}'
    echo ""

    echo -e "${GREEN}[+] Masukkan Nama VPS yang mau ditambah port:${NC}"
    read -p ">> " VPS_NAME

    # Validasi nama
    if ! lxc list | grep -q "$VPS_NAME"; then
        echo -e "${RED}[!] VPS tidak ditemukan!${NC}"
        read -p "Tekan Enter untuk kembali..."
        main_menu
        return
    fi

    echo -e "\n${GREEN}[+] Masukkan Port PUBLIC (Yang dibuka di luar):${NC}"
    read -p ">> " PUBLIC_PORT

    echo -e "\n${GREEN}[+] Masukkan Port INTERNAL (Target di dalam VPS):${NC}"
    echo -e "(Contoh: 80 untuk Web, 3306 untuk MySQL, 22 untuk SSH lain)"
    read -p ">> " INTERNAL_PORT

    echo -e "\n${YELLOW}>>> Menambahkan Port Mapping $PUBLIC_PORT -> $INTERNAL_PORT pada $VPS_NAME...${NC}"

    # Nama device unik biar gak bentrok
    DEVICE_NAME="proxy-$PUBLIC_PORT"

    lxc config device add "$VPS_NAME" "$DEVICE_NAME" proxy listen=tcp:0.0.0.0:"$PUBLIC_PORT" connect=tcp:127.0.0.1:"$INTERNAL_PORT" bind=host
    
    if [ $? -eq 0 ]; then
        echo -e "${BLUE}[INFO] Membuka Firewall UFW...${NC}"
        ufw allow "$PUBLIC_PORT"/tcp > /dev/null
        echo -e "${GREEN}[SUCCESS] Port berhasil dibuka!${NC}"
    else
        echo -e "${RED}[FAIL] Gagal menambah port. Mungkin port $PUBLIC_PORT sudah terpakai.${NC}"
    fi
    read -p "Tekan Enter untuk kembali ke menu..."
    main_menu
}

function hapus_vps() {
    show_header
    echo -e "${RED}[ MENU: HAPUS VPS ]${NC}"

    # List VPS
    lxc list
    echo ""
    
    echo -e "${GREEN}[+] Masukkan Nama VPS yang akan DIHAPUS PERMANEN:${NC}"
    read -p ">> " VPS_NAME

    if ! lxc list | grep -q "$VPS_NAME"; then
        echo -e "${RED}[!] VPS tidak ditemukan!${NC}"
        read -p "Tekan Enter untuk kembali..."
        main_menu
        return
    fi

    echo -e "${RED}[WARNING] Apakah Anda yakin ingin menghapus VPS: $VPS_NAME? (y/n)${NC}"
    read -p ">> " CONFIRM
    if [ "$CONFIRM" != "y" ]; then
        echo "Dibatalkan."
        main_menu
        return
    fi

    echo -e "\n${YELLOW}>>> Mendeteksi port firewall yang digunakan VPS ini...${NC}"
    
    # Deteksi otomatis port yang dipake VPS ini
    PORTS=$(lxc config device show "$VPS_NAME" | grep "listen: tcp:0.0.0.0" | awk -F: '{print $NF}' | tr -d ' ')

    if [ -n "$PORTS" ]; then
        echo -e "${BLUE}Ditemukan port aktif: $PORTS${NC}"
        for PORT in $PORTS; do
            echo -e " -> Menghapus rule UFW untuk port $PORT..."
            ufw delete allow "$PORT"/tcp > /dev/null
        done
    else
        echo -e "${BLUE}Tidak ditemukan port public aktif (atau manual set).${NC}"
    fi

    echo -e "${YELLOW}>>> Menghapus Container $VPS_NAME...${NC}"
    lxc delete "$VPS_NAME" --force
    
    echo -e "${GREEN}[SUCCESS] VPS $VPS_NAME dan port-nya telah dihapus.${NC}"
    read -p "Tekan Enter untuk kembali ke menu..."
    main_menu
}

function main_menu() {
    show_header
    # Panggil cek status di awal
    # check_lxd_status (opsional kalau mau cek setiap kali menu muncul, tapi lebih baik sekali di awal script)

    echo -e "Silakan pilih menu:"
    echo -e "${BLUE}[1]${NC} Buat VPS Baru"
    echo -e "${BLUE}[2]${NC} Tambah Port (Forwarding)"
    echo -e "${BLUE}[3]${NC} Hapus VPS"
    echo -e "${BLUE}[4]${NC} Keluar"
    echo ""
    read -p "Pilihan Anda [1-4]: " MENU_CHOICE

    case $MENU_CHOICE in
        1) buat_vps ;;
        2) tambah_port ;;
        3) hapus_vps ;;
        4) echo "Bye bro!"; exit 0 ;;
        *) main_menu ;;
    esac
}

# --- JALANKAN CHECK DULU ---
show_header
check_lxd_status

# --- MASUK MENU UTAMA ---
main_menu
