#!/bin/bash
set -e

# Load config
source ./config.sh

exec > >(tee -a "$LOGFILE") 2>&1

echo "===================================="
echo " Arch Linux Hyper-V Installer"
echo "===================================="

# ===== INPUT (VEILIGER) =====

read -p "Bevestig disk ($DISK): " CONFIRM_DISK
CONFIRM_DISK=${CONFIRM_DISK:-$DISK}

if [[ "$CONFIRM_DISK" != "$DISK" ]]; then
  echo "Disk mismatch! Aborting."
  exit 1
fi

read -s -p "Root password: " ROOTPASS
echo

read -s -p "User password: " USERPASS
echo

# ===== BASIC SETUP =====

loadkeys $KEYMAP
timedatectl set-ntp true

# ===== PARTITION (WIPE WARNING) =====

echo "WARNING: disk wordt gewist: $DISK"
sleep 2

parted $DISK --script mklabel gpt
parted $DISK --script mkpart ESP fat32 1MiB 513MiB
parted $DISK --script set 1 esp on
parted $DISK --script mkpart primary ext4 513MiB 100%

mkfs.fat -F32 ${DISK}1
mkfs.ext4 -F ${DISK}2

mount ${DISK}2 /mnt
mkdir -p /mnt/boot
mount ${DISK}1 /mnt/boot

# ===== BASE SYSTEM =====

pacstrap /mnt base linux linux-firmware nano sudo networkmanager grub efibootmgr

genfstab -U /mnt >> /mnt/etc/fstab

# ===== CHROOT =====

arch-chroot /mnt /bin/bash <<EOF

set -e

ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

sed -i 's/#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen

echo "LANG=en_US.UTF-8" > /etc/locale.conf

echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf

echo "$HOSTNAME" > /etc/hostname

cat <<EOT > /etc/hosts
127.0.0.1 localhost
::1 localhost
127.0.1.1 $HOSTNAME.localdomain $HOSTNAME
EOT

# USERS
useradd -m -G wheel -s /bin/bash $USERNAME
echo "$USERNAME:$USERPASS" | chpasswd
echo "root:$ROOTPASS" | chpasswd

# SUDO
echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers

# NETWORK
systemctl enable NetworkManager

# BOOTLOADER
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

EOF

echo "===================================="
echo " INSTALL COMPLETED"
echo "===================================="
