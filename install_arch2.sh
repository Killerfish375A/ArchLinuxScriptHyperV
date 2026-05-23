#!/bin/bash

set -e

# ==========================================
# ARCH LINUX AUTO INSTALL (HYPER-V READY)
# ==========================================

clear

echo "======================================="
echo "   Arch Linux Auto Installer"
echo "======================================="
echo

# ========== USER INPUT ==========

read -p "Disk (default: /dev/sda): " DISK
DISK=${DISK:-/dev/sda}

read -p "Hostname: " HOSTNAME
HOSTNAME=${HOSTNAME:-archvm}

read -p "Username: " USERNAME
USERNAME=${USERNAME:-user}

echo
read -s -p "User password: " USERPASS
echo

read -s -p "Root password: " ROOTPASS
echo

# ========== SETTINGS ==========

TIMEZONE="Europe/Amsterdam"
KEYMAP="us"

# ========== SHOW CONFIG ==========

echo
echo "======================================="
echo " INSTALL SETTINGS"
echo "======================================="
echo "Disk      : $DISK"
echo "Hostname  : $HOSTNAME"
echo "Username  : $USERNAME"
echo "Timezone  : $TIMEZONE"
echo "Keyboard  : $KEYMAP"
echo "======================================="
echo

read -p "Continue installation? (y/n): " CONFIRM

if [[ "$CONFIRM" != "y" ]]; then
    echo "Installation cancelled."
    exit 1
fi

# ========== BASIC SETUP ==========

loadkeys $KEYMAP

timedatectl set-ntp true

# ========== PARTITIONING ==========

echo
echo "Partitioning disk..."

parted $DISK --script mklabel gpt
parted $DISK --script mkpart ESP fat32 1MiB 513MiB
parted $DISK --script set 1 esp on
parted $DISK --script mkpart primary ext4 513MiB 100%

# ========== FORMAT ==========

echo "Formatting partitions..."

mkfs.fat -F32 ${DISK}1
mkfs.ext4 -F ${DISK}2

# ========== MOUNT ==========

echo "Mounting partitions..."

mount ${DISK}2 /mnt

mkdir -p /mnt/boot

mount ${DISK}1 /mnt/boot

# ========== INSTALL BASE SYSTEM ==========

echo
echo "Installing base system..."

pacstrap /mnt \
base \
linux \
linux-firmware \
nano \
sudo \
networkmanager \
grub \
efibootmgr

# ========== FSTAB ==========

genfstab -U /mnt >> /mnt/etc/fstab

# ========== CHROOT CONFIGURATION ==========

echo
echo "Configuring system..."

arch-chroot /mnt /bin/bash <<EOF

set -e

# ---------- TIMEZONE ----------

ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

# ---------- LOCALE ----------

sed -i 's/#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
sed -i 's/#nl_NL.UTF-8/nl_NL.UTF-8/' /etc/locale.gen

locale-gen

echo "LANG=en_US.UTF-8" > /etc/locale.conf

# ---------- KEYBOARD ----------

echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf

# ---------- HOSTNAME ----------

echo "$HOSTNAME" > /etc/hostname

cat <<EOT > /etc/hosts
127.0.0.1 localhost
::1 localhost
127.0.1.1 $HOSTNAME.localdomain $HOSTNAME
EOT

# ---------- USERS ----------

useradd -m -G wheel -s /bin/bash $USERNAME

echo "$USERNAME:$USERPASS" | chpasswd
echo "root:$ROOTPASS" | chpasswd

# ---------- SUDO ----------

echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers

# ---------- NETWORK ----------

systemctl enable NetworkManager

# ---------- BOOTLOADER ----------

grub-install \
--target=x86_64-efi \
--efi-directory=/boot \
--bootloader-id=GRUB

grub-mkconfig -o /boot/grub/grub.cfg

EOF

# ========== FINISHED ==========

echo
echo "======================================="
echo " INSTALLATION COMPLETE"
echo "======================================="
echo
echo "You can now reboot:"
echo
echo "    reboot"
echo
echo "Remove the ISO after shutdown."
echo