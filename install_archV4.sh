#!/bin/bash
set -e

# ====================================
# Arch Linux Hyper-V Installer v4
# ====================================

# Load config
source ./config.sh

LOGFILE=${LOGFILE:-/var/log/install.log}
exec > >(tee -a "$LOGFILE") 2>&1

echo "===================================="
echo " Arch Linux Hyper-V Installer v4"
echo "===================================="

echo ""
echo "⚠️  WARNING: FULL DISK WILL BE ERASED"
echo "Target disk: $DISK"
echo "Hostname: $HOSTNAME"
echo ""

# ===== SIMPLE SAFETY CONFIRM =====

read -p "Type YES to continue: " CONFIRM

if [[ "$CONFIRM" != "YES" ]]; then
  echo "❌ Aborted."
  exit 1
fi

# ===== SYSTEM SETUP =====

loadkeys "$KEYMAP"
timedatectl set-ntp true

# ===== PARTITIONING =====

echo "📦 Wiping and partitioning disk..."

parted "$DISK" --script mklabel gpt
parted "$DISK" --script mkpart ESP fat32 1MiB 513MiB
parted "$DISK" --script set 1 esp on
parted "$DISK" --script mkpart primary ext4 513MiB 100%

mkfs.fat -F32 "${DISK}1"
mkfs.ext4 -F "${DISK}2"

mount "${DISK}2" /mnt
mkdir -p /mnt/boot
mount "${DISK}1" /mnt/boot

# ===== BASE SYSTEM =====

pacstrap /mnt \
  base linux linux-firmware \
  nano sudo networkmanager \
  grub efibootmgr

genfstab -U /mnt >> /mnt/etc/fstab

# ===== CHROOT =====

arch-chroot /mnt /bin/bash <<EOF

set -e

echo "🌍 Timezone..."
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

echo "🌐 Locale..."
sed -i 's/#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

echo "⌨ Keyboard..."
echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf

echo "🏷 Hostname..."
echo "$HOSTNAME" > /etc/hostname

cat <<EOT > /etc/hosts
127.0.0.1 localhost
::1 localhost
127.0.0.1 $HOSTNAME.localdomain $HOSTNAME
EOT

# ===== USERS =====

echo "👤 User setup..."
useradd -m -G wheel -s /bin/bash "$USERNAME"

echo "$USERNAME:$USERPASS" | chpasswd
echo "root:$ROOTPASS" | chpasswd

# ===== SUDO SAFE =====

echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel

# ===== NETWORK =====

systemctl enable NetworkManager

# ===== BOOTLOADER (UEFI) =====

mkdir -p /boot/efi

grub-install \
  --target=x86_64-efi \
  --efi-directory=/boot \
  --bootloader-id=GRUB

grub-mkconfig -o /boot/grub/grub.cfg

EOF

echo "===================================="
echo " INSTALL COMPLETED SUCCESSFULLY"
echo "===================================="
