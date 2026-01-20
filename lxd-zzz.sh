#!/bin/bash

# ==========================================
#   LXD Zzz VPS MANAGER v1.1
#   Copyright (c) Muhammad Zili
#   Automated LXD Container Creator
# ==========================================

# Warna biar ganteng (Disederhanakan penggunaannya)
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Trap Ctrl+C agar exit rapi
trap "echo -e '\n${RED}[!] Script dihentikan user.${NC}'; exit" SIGINT

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
    # 1. Cek apakah LXD terinstall
    if ! command -v lxd &> /dev/null; then
        echo -e "${YELLOW}[!] LXD tidak ditemukan. Menginstall LXD...${NC}"
        apt-get update > /dev/null 2>&1
        snap install lxd
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}[OK] LXD berhasil diinstall.${NC}"
        else
            echo -e "${RED}[FAIL] Gagal menginstall LXD.${NC}"
            exit 1
        fi
    fi

    # 2. Cek apakah LXD sudah di-init
    if ! lxc list &> /dev/null; then
        echo -e "\n${YELLOW}[!] LXD belum diinisialisasi.${NC}"
        echo -e "Script akan menjalankan 'lxd init'. Tekan ${GREEN}ENTER${NC} untuk opsi default."
        echo -e "Penting: Pilih 'yes' saat ditanya 'Create a new zfs pool?'."
        read -p "Tekan Enter untuk memulai..."
        lxd init
        echo -e "\n${GREEN}[OK] Selesai.${NC}"
    fi
}

function show_header() {
    clear
    echo -e "${CYAN}=================================================${NC}"
    echo -e "${YELLOW}           LXD Zzz - VPS MANAGER v1.1            ${NC}"
    echo -e "${CYAN}=================================================${NC}"
    echo ""
}

# --- MENU: BUAT VPS ---
function buat_vps() {
    show_header
    echo -e "${GREEN}[ BUAT VPS BARU ]${NC}"
    
    echo -e "Masukkan Nama VPS (Hostname):"
    read -p ">> " VPS_NAME

    if [[ -z "$VPS_NAME" ]]; then
        echo -e "${RED}[!] Nama tidak boleh kosong!${NC}"
        read -p "Enter..."
        main_menu
        return
    fi

    if lxc list | grep -q "$VPS_NAME"; then
        echo -e "${RED}[!] Error: Nama $VPS_NAME sudah ada!${NC}"
        read -p "Enter..."
        main_menu
        return
    fi

    echo -e "\nMasukkan Port SSH Custom (Cth: 1248):"
    read -p ">> " SSH_PORT

    echo -e "\nPilih OS:"
    echo -e "1. Ubuntu 22.04 LTS"
    echo -e "2. Ubuntu 20.04 LTS"
    echo -e "3. Ubuntu 24.04 LTS"
    echo -e "4. Debian 11"
    read -p "Pilih [1-4]: " OS_CHOICE

    case $OS_CHOICE in
        1) IMAGE="ubuntu:22.04" ;;
        2) IMAGE="ubuntu:20.04" ;;
        3) IMAGE="ubuntu:24.04" ;;
        4) IMAGE="images:debian/11" ;;
        *) IMAGE="ubuntu:22.04" ;;
    esac

    echo -e "\nPilih Paket Resource:"
    echo -e "1. Kecil    (1GB RAM, 5GB Disk, 1 CPU)"
    echo -e "2. Menengah (3GB RAM, 20GB Disk, 2 CPU)"
    echo -e "3. Besar    (5GB RAM, 40GB Disk, 3 CPU)"
    echo -e "4. Custom"
    read -p "Pilih [1-4]: " PAKET

    case $PAKET in
        1) RAM="1GB"; DISK="5GB"; CPU="1" ;;
        2) RAM="3GB"; DISK="20GB"; CPU="2" ;;
        3) RAM="5GB"; DISK="40GB"; CPU="3" ;;
        4)
            read -p "RAM (cth: 2GB): " RAM
            read -p "Disk (cth: 15GB): " DISK
            read -p "CPU (cth: 2): " CPU
            ;;
        *) echo -e "${RED}Pilihan salah!${NC}"; return ;;
    esac

    echo -e "\n${YELLOW}>>> Membuat VPS: $VPS_NAME...${NC}"

    echo -n "Installing... "
    lxc launch "$IMAGE" "$VPS_NAME" > /dev/null 2>&1 &
    PID=$!
    spinner $PID
    wait $PID
    
    if lxc list | grep -q "$VPS_NAME"; then
        echo -e "${GREEN}[OK]${NC}"
    else
        echo -e "${RED}[FAIL] Gagal membuat container.${NC}"
        read -p "Enter..."
        return
    fi

    echo -e "Mengatur konfigurasi..."
    sleep 3

    # Limit Resource
    lxc config set "$VPS_NAME" limits.memory "$RAM"
    lxc config set "$VPS_NAME" limits.cpu "$CPU"
    lxc config device override "$VPS_NAME" root size="$DISK" 2>/dev/null || lxc config device add "$VPS_NAME" root disk path=/ pool=default size="$DISK"

    # Port Forwarding
    lxc config device add "$VPS_NAME" ssh-proxy proxy listen=tcp:0.0.0.0:"$SSH_PORT" connect=tcp:127.0.0.1:22 bind=host

    # Firewall
    ufw allow "$SSH_PORT"/tcp > /dev/null

    # Patching SSH
    lxc exec "$VPS_NAME" -- rm -f /etc/ssh/sshd_config.d/50-cloud-init.conf
    lxc exec "$VPS_NAME" -- rm -f /etc/ssh/sshd_config.d/60-cloudimg-settings.conf
    lxc exec "$VPS_NAME" -- sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
    lxc exec "$VPS_NAME" -- sed -i 's/PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
    lxc exec "$VPS_NAME" -- sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
    lxc exec "$VPS_NAME" -- sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
    lxc exec "$VPS_NAME" -- systemctl restart ssh

    echo -e "\n${YELLOW}=== SET PASSWORD ROOT ===${NC}"
    lxc exec "$VPS_NAME" -- passwd root

    IP_PUBLIC=$(curl -s ifconfig.me)
    echo -e "\n${GREEN}VPS SELESAI DIBUAT${NC}"
    echo -e "Login: ssh root@$IP_PUBLIC -p $SSH_PORT"
    read -p "Enter untuk kembali..."
    main_menu
}

# --- MENU: KELOLA VPS ---
function kelola_vps() {
    show_header
    echo -e "${GREEN}[ KELOLA VPS ]${NC}"
    echo -e "Daftar VPS:"
    # Tampilan list lebih bersih (Nama, Status, IPv4)
    lxc list -c n,s,4 | grep RUNNING
    echo ""
    
    echo -e "1. Info Detail"
    echo -e "2. Start VPS"
    echo -e "3. Stop VPS"
    echo -e "4. Restart VPS"
    echo -e "5. Kembali"
    read -p "Pilih [1-5]: " OPSI_KELOLA

    case $OPSI_KELOLA in
        1)
            read -p "Nama VPS: " TARGET
            lxc info "$TARGET" | head -n 20 # Batasi output biar ga kepanjangan
            ;;
        2)
            read -p "Nama VPS: " TARGET
            lxc start "$TARGET" && echo -e "${GREEN}OK${NC}" || echo -e "${RED}Gagal${NC}"
            ;;
        3)
            read -p "Nama VPS: " TARGET
            lxc stop "$TARGET" && echo -e "${GREEN}OK${NC}" || echo -e "${RED}Gagal${NC}"
            ;;
        4)
            read -p "Nama VPS: " TARGET
            lxc restart "$TARGET" && echo -e "${GREEN}OK${NC}" || echo -e "${RED}Gagal${NC}"
            ;;
        5) main_menu ;;
        *) kelola_vps ;;
    esac
    read -p "Enter untuk lanjut..."
    kelola_vps
}

# --- MENU: BACKUP & RESTORE ---
function backup_restore() {
    show_header
    echo -e "${GREEN}[ BACKUP & RESTORE ]${NC}"
    echo -e "1. Buat Snapshot"
    echo -e "2. Restore Snapshot"
    echo -e "3. List Snapshot"
    echo -e "4. Kembali"
    read -p "Pilih [1-4]: " OPSI_BACKUP

    case $OPSI_BACKUP in
        1)
            lxc list -c n,s | grep RUNNING
            echo ""
            read -p "Target VPS: " TARGET
            read -p "Nama Backup (cth: backup1): " SNAP_NAME
            # Validasi nama snapshot (hilangkan spasi jika ada)
            SNAP_NAME=${SNAP_NAME// /_}
            echo -n "Memproses... "
            lxc snapshot "$TARGET" "$SNAP_NAME" && echo -e "${GREEN}Sukses!${NC}" || echo -e "${RED}Gagal!${NC}"
            ;;
        2)
            read -p "Target VPS: " TARGET
            lxc info "$TARGET" | grep "Snapshots:" -A 10
            echo ""
            read -p "Nama Backup utk Restore: " SNAP_NAME
            echo -e "${RED}Data akan kembali ke titik backup!${NC}"
            read -p "Lanjut? (y/n): " SURE
            if [[ "$SURE" == "y" ]]; then
                lxc restore "$TARGET" "$SNAP_NAME" && echo -e "${GREEN}Sukses!${NC}" || echo -e "${RED}Gagal!${NC}"
            fi
            ;;
        3)
            read -p "Target VPS: " TARGET
            echo "Daftar Backup:"
            lxc info "$TARGET" | grep "Snapshots:" -A 20
            ;;
        4) main_menu ;;
        *) backup_restore ;;
    esac
    read -p "Enter untuk lanjut..."
    backup_restore
}

# --- MENU: TAMBAH PORT ---
function tambah_port() {
    show_header
    echo -e "${GREEN}[ TAMBAH PORT ]${NC}"
    lxc list -c n,s | grep RUNNING | awk '{print $2}'
    echo ""

    read -p "Nama VPS: " VPS_NAME
    if ! lxc list | grep -q "$VPS_NAME"; then
        echo -e "${RED}VPS tidak ditemukan!${NC}"
        read -p "Enter..."
        main_menu
        return
    fi

    echo -e "Port PUBLIC (Luar):"
    read -p ">> " PUBLIC_PORT
    echo -e "Port INTERNAL (Dalam VPS):"
    read -p ">> " INTERNAL_PORT

    DEVICE_NAME="proxy-$PUBLIC_PORT"
    lxc config device add "$VPS_NAME" "$DEVICE_NAME" proxy listen=tcp:0.0.0.0:"$PUBLIC_PORT" connect=tcp:127.0.0.1:"$INTERNAL_PORT" bind=host
    
    if [ $? -eq 0 ]; then
        ufw allow "$PUBLIC_PORT"/tcp > /dev/null
        echo -e "${GREEN}Sukses! Port $PUBLIC_PORT -> $INTERNAL_PORT${NC}"
    else
        echo -e "${RED}Gagal! Port mungkin terpakai.${NC}"
    fi
    read -p "Enter..."
    main_menu
}

# --- MENU: HAPUS VPS ---
function hapus_vps() {
    show_header
    echo -e "${RED}[ HAPUS VPS ]${NC}"
    lxc list -c n,s
    echo ""
    
    read -p "Nama VPS: " VPS_NAME
    if ! lxc list | grep -q "$VPS_NAME"; then
        echo -e "${RED}VPS tidak ditemukan!${NC}"
        read -p "Enter..."
        main_menu
        return
    fi

    read -p "YAKIN HAPUS PERMANEN? (y/n): " CONFIRM
    if [ "$CONFIRM" != "y" ]; then
        main_menu
        return
    fi

    echo -e "Membersihkan..."
    # Auto clean firewall ports
    PORTS=$(lxc config device show "$VPS_NAME" | grep "listen: tcp:0.0.0.0" | awk -F: '{print $NF}' | tr -d ' ')

    if [ -n "$PORTS" ]; then
        for PORT in $PORTS; do
            ufw delete allow "$PORT"/tcp > /dev/null
        done
    fi

    lxc delete "$VPS_NAME" --force
    echo -e "${GREEN}Terhapus.${NC}"
    read -p "Enter..."
    main_menu
}

function main_menu() {
    show_header
    # Tampilan menu bersih tanpa tag warna-warni berlebih
    echo -e "1. Buat VPS Baru"
    echo -e "2. Kelola VPS (Start/Stop/Info)"
    echo -e "3. Tambah Port (Forwarding)"
    echo -e "4. Backup & Restore (Snapshot)"
    echo -e "5. Hapus VPS"
    echo -e "6. Keluar"
    echo ""
    read -p "Pilih [1-6]: " MENU_CHOICE

    case $MENU_CHOICE in
        1) buat_vps ;;
        2) kelola_vps ;;
        3) tambah_port ;;
        4) backup_restore ;;
        5) hapus_vps ;;
        6) echo "Bye bro!"; exit 0 ;;
        *) main_menu ;;
    esac
}

# --- START ---
check_lxd_status
main_menu
