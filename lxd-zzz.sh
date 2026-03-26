#!/usr/bin/env bash

# ==========================================
#   LXD Zzz VPS MANAGER v2.0
#   Automated LXD Container Creator & Manager
# ==========================================

# --- COLORS & STYLES ---
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly YELLOW='\033[1;33m'
readonly BOLD='\033[1m'
readonly NC='\033[0m' # No Color

# --- TRAP SIGNALS ---
trap "echo -e '\n${RED}[!] Script terminated by user.${NC}'; exit 0" SIGINT SIGTERM

# ==========================================
#   UTILITY FUNCTIONS
# ==========================================

print_info() { echo -e "${CYAN}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_header() {
    clear
    echo -e "${CYAN}=================================================${NC}"
    echo -e "${YELLOW}${BOLD}            LXD Zzz - VPS MANAGER v2.0           ${NC}"
    echo -e "${CYAN}=================================================${NC}\n"
}

pause_and_continue() {
    echo ""
    read -p "Press [Enter] to return to the menu..."
}

# Advanced Spinner for background tasks
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    echo -n " "
    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Validate if string is a valid number (for ports/limits)
is_numeric() {
    [[ "$1" =~ ^[0-9]+$ ]]
}

# Validate container name (alphanumeric and dashes only)
is_valid_name() {
    [[ "$1" =~ ^[a-zA-Z0-9-]+$ ]]
}

# Check if a container exists
container_exists() {
    lxc info "$1" >/dev/null 2>&1
}

# ==========================================
#   CORE SETUP FUNCTIONS
# ==========================================

check_dependencies() {
    if ! command -v curl &> /dev/null; then
        print_info "Installing required package: curl"
        apt-get update > /dev/null 2>&1 && apt-get install -y curl > /dev/null 2>&1
    fi
}

check_lxd_status() {
    if ! command -v lxd &> /dev/null; then
        print_warning "LXD not found. Installing LXD via snap..."
        apt-get update > /dev/null 2>&1
        if snap install lxd; then
            print_success "LXD installed successfully."
        else
            print_error "Failed to install LXD. Please install it manually."
            exit 1
        fi
    fi

    if ! lxc list &> /dev/null; then
        print_warning "LXD is not initialized."
        echo -e "The script will run 'lxd init'. Press ${GREEN}ENTER${NC} to use default options."
        read -p "Press Enter to start..."
        lxd init
    fi
}

# ==========================================
#   MODULE: CREATE VPS
# ==========================================

create_vps() {
    print_header
    echo -e "${GREEN}${BOLD}[ CREATE NEW VPS ]${NC}\n"

    # Get VPS Name
    local vps_name
    read -p "Enter VPS Name (Hostname): " vps_name
    
    if [[ -z "$vps_name" ]] || ! is_valid_name "$vps_name"; then
        print_error "Invalid name! Use only letters, numbers, and dashes."
        pause_and_continue
        return
    fi

    if container_exists "$vps_name"; then
        print_error "VPS name '$vps_name' already exists!"
        pause_and_continue
        return
    fi

    # Get SSH Port
    local ssh_port
    read -p "Enter custom SSH Port (e.g., 2201): " ssh_port
    if ! is_numeric "$ssh_port"; then
        print_error "Invalid port number!"
        pause_and_continue
        return
    fi

    # Choose OS
    echo -e "\n${CYAN}Select Operating System:${NC}"
    echo "1. Ubuntu 22.04 LTS (Default)"
    echo "2. Ubuntu 20.04 LTS"
    echo "3. Ubuntu 24.04 LTS"
    echo "4. Debian 11"
    local os_choice
    read -p "Choice [1-4]: " os_choice

    local image="ubuntu:22.04"
    case $os_choice in
        2) image="ubuntu:20.04" ;;
        3) image="ubuntu:24.04" ;;
        4) image="images:debian/11" ;;
    esac

    # Choose Resources
    echo -e "\n${CYAN}Select Resource Package:${NC}"
    echo "1. Small  (1GB RAM, 5GB Disk, 1 CPU)"
    echo "2. Medium (3GB RAM, 20GB Disk, 2 CPU)"
    echo "3. Large  (5GB RAM, 40GB Disk, 3 CPU)"
    echo "4. Custom"
    local pkg_choice ram disk cpu
    read -p "Choice [1-4]: " pkg_choice

    case $pkg_choice in
        1) ram="1GB"; disk="5GB"; cpu="1" ;;
        2) ram="3GB"; disk="20GB"; cpu="2" ;;
        3) ram="5GB"; disk="40GB"; cpu="3" ;;
        4)
            read -p "RAM (e.g., 2GB): " ram
            read -p "Disk (e.g., 15GB): " disk
            read -p "CPU Cores (e.g., 2): " cpu
            ;;
        *) print_error "Invalid choice!"; pause_and_continue; return ;;
    esac

    echo -e "\n${YELLOW}>>> Creating VPS: ${vps_name} ...${NC}"
    
    echo -n "Downloading image and launching... "
    lxc launch "$image" "$vps_name" > /dev/null 2>&1 &
    local pid=$!
    spinner $pid
    wait $pid

    if ! container_exists "$vps_name"; then
        print_error "Failed to create container."
        pause_and_continue
        return
    fi
    print_success "Container launched."

    echo -e "Configuring resources and networking..."
    sleep 3 # Wait for container filesystem to be fully ready

    # Apply Limits
    lxc config set "$vps_name" limits.memory "$ram"
    lxc config set "$vps_name" limits.cpu "$cpu"
    lxc config device override "$vps_name" root size="$disk" 2>/dev/null || lxc config device add "$vps_name" root disk path=/ pool=default size="$disk"

    # Setup SSH Port Forwarding
    lxc config device add "$vps_name" ssh-proxy proxy listen=tcp:0.0.0.0:"$ssh_port" connect=tcp:127.0.0.1:22 bind=host
    
    # Configure Firewall (UFW)
    if command -v ufw >/dev/null; then
        ufw allow "$ssh_port"/tcp > /dev/null 2>&1
    fi

    # Patch SSH Config inside container to allow Root & Password Login
    lxc exec "$vps_name" -- bash -c "rm -f /etc/ssh/sshd_config.d/50-cloud-init.conf /etc/ssh/sshd_config.d/60-cloudimg-settings.conf"
    lxc exec "$vps_name" -- bash -c "sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config"
    lxc exec "$vps_name" -- bash -c "sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config"
    lxc exec "$vps_name" -- systemctl restart ssh

    echo -e "\n${YELLOW}=== SET ROOT PASSWORD ===${NC}"
    lxc exec "$vps_name" -- passwd root

    local ip_public
    ip_public=$(curl -s ifconfig.me || echo "YOUR_SERVER_IP")
    
    echo -e "\n${GREEN}${BOLD}VPS SUCCESSFULLY CREATED!${NC}"
    echo -e "------------------------------------------------"
    echo -e "Hostname : $vps_name"
    echo -e "OS       : $image"
    echo -e "Specs    : $cpu Core(s), $ram RAM, $disk Disk"
    echo -e "Login    : ${CYAN}ssh root@${ip_public} -p ${ssh_port}${NC}"
    echo -e "------------------------------------------------"
    pause_and_continue
}

# ==========================================
#   MODULE: MANAGE VPS
# ==========================================

manage_vps() {
    while true; do
        print_header
        echo -e "${GREEN}${BOLD}[ MANAGE VPS ]${NC}\n"
        
        # Show running containers
        echo -e "${CYAN}Running Containers:${NC}"
        lxc list -c n,s,4 | grep RUNNING || echo "No running containers."
        echo ""

        echo "1. Detailed Info"
        echo "2. Start VPS"
        echo "3. Stop VPS"
        echo "4. Restart VPS"
        echo "5. Set Bandwidth Limit"
        echo "6. Reinstall OS"
        echo "7. Back to Main Menu"
        
        local choice target
        read -p "Choice [1-7]: " choice

        # Exit sub-menu
        if [[ "$choice" == "7" ]]; then return; fi

        # Prompt for target VPS for actions 1-6
        if [[ "$choice" =~ ^[1-6]$ ]]; then
            read -p "Enter VPS Name: " target
            if ! container_exists "$target"; then
                print_error "VPS '$target' does not exist."
                sleep 2
                continue
            fi
        fi

        case $choice in
            1)
                echo -e "\n${BLUE}--- Detailed Information for $target ---${NC}"
                lxc info "$target" | grep -v "Snapshots" | head -n 30
                pause_and_continue
                ;;
            2)
                echo -n "Starting $target... "
                lxc start "$target" && print_success "OK" || print_error "Failed"
                sleep 2
                ;;
            3)
                echo -n "Stopping $target... "
                lxc stop "$target" && print_success "OK" || print_error "Failed"
                sleep 2
                ;;
            4)
                echo -n "Restarting $target... "
                lxc restart "$target" && print_success "OK" || print_error "Failed"
                sleep 2
                ;;
            5)
                echo -e "\n${CYAN}Format: 10Mbit, 100Mbit, 1Gbit (Leave blank for Unlimited)${NC}"
                local limit_in limit_out
                read -p "Download Limit (Ingress): " limit_in
                read -p "Upload Limit (Egress): " limit_out

                # Check and handle eth0 device
                if [[ -n "$limit_in" ]]; then
                    lxc config device override "$target" eth0 limits.ingress="$limit_in" 2>/dev/null || \
                    lxc config device set "$target" eth0 limits.ingress="$limit_in" 2>/dev/null || \
                    lxc config device add "$target" eth0 nic nictype=bridged parent=lxdbr0 limits.ingress="$limit_in"
                fi

                if [[ -n "$limit_out" ]]; then
                    lxc config device override "$target" eth0 limits.egress="$limit_out" 2>/dev/null || \
                    lxc config device set "$target" eth0 limits.egress="$limit_out" 2>/dev/null || \
                    lxc config device add "$target" eth0 nic nictype=bridged parent=lxdbr0 limits.egress="$limit_out"
                fi
                print_success "Bandwidth limits applied successfully."
                pause_and_continue
                ;;
            6)
                echo -e "\n${RED}${BOLD}[WARNING] All data inside '$target' will be ERASED!${NC}"
                echo "Configuration (IP, Ports, Limits) will remain intact."
                local confirm
                read -p "Type 'YES' to proceed: " confirm
                
                if [[ "$confirm" == "YES" ]]; then
                    echo -n "Reinstalling OS (Ubuntu 22.04)... "
                    if lxc rebuild ubuntu:22.04 "$target" > /dev/null 2>&1; then
                        print_success "Rebuild completed."
                        echo -e "Re-applying SSH configuration..."
                        lxc exec "$target" -- bash -c "rm -f /etc/ssh/sshd_config.d/50-cloud-init.conf"
                        lxc exec "$target" -- bash -c "sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config"
                        lxc exec "$target" -- bash -c "sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config"
                        lxc exec "$target" -- systemctl restart ssh
                        
                        echo -e "\n${YELLOW}=== SET NEW ROOT PASSWORD ===${NC}"
                        lxc exec "$target" -- passwd root
                    else
                        print_error "Failed to rebuild VPS."
                    fi
                else
                    print_info "Reinstallation cancelled."
                fi
                pause_and_continue
                ;;
            *)
                print_error "Invalid option."
                sleep 1
                ;;
        esac
    done
}

# ==========================================
#   MODULE: PORT FORWARDING
# ==========================================

add_port_forwarding() {
    print_header
    echo -e "${GREEN}${BOLD}[ ADD PORT FORWARDING ]${NC}\n"
    
    echo -e "${CYAN}Available Containers:${NC}"
    lxc list -c n,s | grep RUNNING | awk '{print $2}' || echo "No running containers."
    echo ""

    local vps_name
    read -p "Enter VPS Name: " vps_name
    
    if ! container_exists "$vps_name"; then
        print_error "VPS '$vps_name' not found!"
        pause_and_continue
        return
    fi

    local public_port internal_port
    read -p "Public Port (External): " public_port
    read -p "Internal Port (Inside VPS): " internal_port

    if ! is_numeric "$public_port" || ! is_numeric "$internal_port"; then
        print_error "Ports must be numbers!"
        pause_and_continue
        return
    fi

    local device_name="proxy-${public_port}"
    if lxc config device add "$vps_name" "$device_name" proxy listen=tcp:0.0.0.0:"$public_port" connect=tcp:127.0.0.1:"$internal_port" bind=host 2>/dev/null; then
        if command -v ufw >/dev/null; then
            ufw allow "$public_port"/tcp > /dev/null 2>&1
        fi
        print_success "Port forwarded: Host($public_port) -> VPS($internal_port)"
    else
        print_error "Failed! Port might already be in use or device name exists."
    fi
    
    pause_and_continue
}

# ==========================================
#   MODULE: BACKUP & RESTORE
# ==========================================

manage_snapshots() {
    while true; do
        print_header
        echo -e "${GREEN}${BOLD}[ BACKUP & RESTORE ]${NC}\n"
        
        echo "1. Create Snapshot (Backup)"
        echo "2. Restore Snapshot"
        echo "3. List Snapshots"
        echo "4. Back to Main Menu"
        
        local choice target snap_name
        read -p "Choice [1-4]: " choice

        if [[ "$choice" == "4" ]]; then return; fi

        if [[ "$choice" =~ ^[1-3]$ ]]; then
            read -p "Enter Target VPS: " target
            if ! container_exists "$target"; then
                print_error "VPS '$target' not found."
                sleep 2
                continue
            fi
        fi

        case $choice in
            1)
                read -p "Snapshot Name (e.g., backup-01): " snap_name
                snap_name=${snap_name// /_} # Replace spaces with underscores
                echo -n "Creating snapshot... "
                if lxc snapshot "$target" "$snap_name"; then
                    print_success "Snapshot '$snap_name' created."
                else
                    print_error "Failed to create snapshot."
                fi
                pause_and_continue
                ;;
            2)
                echo -e "\n${CYAN}Available Snapshots:${NC}"
                lxc info "$target" | grep -A 10 "Snapshots:" || echo "No snapshots found."
                echo ""
                
                read -p "Enter Snapshot Name to Restore: " snap_name
                echo -e "${RED}[WARNING] Current data will be replaced by the backup!${NC}"
                local confirm
                read -p "Are you sure? (y/n): " confirm
                
                if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                    echo -n "Restoring... "
                    if lxc restore "$target" "$snap_name"; then
                        print_success "Restored successfully."
                    else
                        print_error "Restore failed."
                    fi
                else
                    print_info "Restore cancelled."
                fi
                pause_and_continue
                ;;
            3)
                echo -e "\n${CYAN}Snapshot List for $target:${NC}"
                lxc info "$target" | grep -A 20 "Snapshots:" || echo "No snapshots found."
                pause_and_continue
                ;;
            *)
                print_error "Invalid option."
                sleep 1
                ;;
        esac
    done
}

# ==========================================
#   MODULE: DELETE VPS
# ==========================================

delete_vps() {
    print_header
    echo -e "${RED}${BOLD}[ DELETE VPS ]${NC}\n"
    
    lxc list -c n,s
    echo ""
    
    local vps_name
    read -p "Enter VPS Name to delete: " vps_name
    
    if ! container_exists "$vps_name"; then
        print_error "VPS '$vps_name' not found!"
        pause_and_continue
        return
    fi

    local confirm
    read -p "PERMANENTLY DELETE '$vps_name'? (Type 'y' to confirm): " confirm
    
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        print_info "Deletion cancelled."
        pause_and_continue
        return
    fi

    echo -e "Cleaning up resources..."
    
    # Safely parse and remove UFW rules associated with proxy devices
    local ports
    ports=$(lxc config device show "$vps_name" | awk '/listen: tcp:0.0.0.0:/ {print $NF}' | cut -d: -f4)
    
    if [[ -n "$ports" && -x "$(command -v ufw)" ]]; then
        for port in $ports; do
            ufw delete allow "$port"/tcp > /dev/null 2>&1
            echo "Removed UFW rule for port $port"
        done
    fi

    # Force delete the container
    if lxc delete "$vps_name" --force; then
        print_success "VPS '$vps_name' has been completely deleted."
    else
        print_error "Failed to delete VPS."
    fi
    
    pause_and_continue
}

# ==========================================
#   MAIN EXECUTION
# ==========================================

main() {
    # Initialization checks
    check_dependencies
    check_lxd_status

    # Main Menu Loop
    while true; do
        print_header
        echo "1. Create New VPS"
        echo "2. Manage VPS (Limits/Reinstall/Info)"
        echo "3. Add Port Forwarding"
        echo "4. Backup & Restore (Snapshots)"
        echo "5. Delete VPS"
        echo "6. Exit"
        echo ""
        
        local menu_choice
        read -p "Choice [1-6]: " menu_choice

        case $menu_choice in
            1) create_vps ;;
            2) manage_vps ;;
            3) add_port_forwarding ;;
            4) manage_snapshots ;;
            5) delete_vps ;;
            6) 
                echo -e "\n${GREEN}Goodbye!${NC}"
                exit 0 
                ;;
            *) 
                print_error "Invalid option, please select 1-6."
                sleep 1
                ;;
        esac
    done
}

# Start script
main
