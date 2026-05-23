Downloaden in Arch Linux:

curl -O https://raw.githubusercontent.com/JOUWNAAM/arch-install/main/install_arch.sh
of
wget https://raw.githubusercontent.com/JOUWNAAM/arch-install/main/install_arch.sh

Uitvoerbaar maken:
chmod +x install_arch.sh

Script starten:
./install_arch.sh

Indien fout:
./install_arch.sh: bad interpreter

Oplossing: fix met dos2unix
Installeer tool:
pacman -S dos2unix
Fix script:
dos2unix install_arch.sh
Run daarna:
./install_arch.sh
