installation:

(GPT. boot in UEFI mode first)
1) partition disks
use one of these tools cfdisk, cgdisk, fdisk, gdisk, sfdisk. enter partition code if prompted by partition editor
	a) create gpt table
	b) create EFI partition for boot directory. partition code - ef00, size - 128MB (recommended size)
	c) (optional) create swap partition. partition code - 8200
	d) format rest of the partition to "Linux". partition code 8300

2) create filesystems in partitions
	a) efi partition (fat32 filesystem) - mkfs.fat -F32 <efi partition>
	b) mkswap <swap partition> (create swap)
	c) mkfs.ext4 <linux partition>

3) mounting
	b) mount "linux" in /mnt
	c) mkdir /mnt/boot
	d) mount efi partition in /mnt/boot
	e) swapon (enable swap partition)

4) check network connection (ping a wan service first). wifi-menu or any other available networkmanager
5) open /etc/pacman.conf and uncomment the [multilib] line and the line below it
6) pacman -Sy (to refresh the repos)
7) (base systems) pacstrap /mnt/ base base-devel devel linux linux-{headers,docs} networkmanager iw net-tools dkms broadcom-wl-dkms vim pulseaudio efi{var,bootmgr} grub sudo os-prober
8) (optional. can be done after installation as well but on live use pacstrap) install a Desktop environment or window manager and a soundmanager.
	Desktop environment:

		i) KDE - sddm (desktop/lockscreen manager), sddm-kcm (sddm configuration util), plasma-desktop, ark (srchive tool), spectacle (screenshot util), kdeplasma-addons (plasma widgets), plasma-pa (pulse audio controller in plasma), kinfocenter (computer info provider), gwenview (gallery), okular (pdf reader), kwalletmanager, konsole (kde terminal)

		ii) mate - lightdm (desktop/lockscreen manager), pacman -Sy mat{e,e-extra} (mate and mate-extra group apps)

		iii) cinnamon - pacman -Sy $(pacman -Ssq cinnamon)

		iv) deepin - pacman -Sy deepi{n,n-extra} (deepin & deepin-extra groups)

		v) gnome - pacman -Sy gnome gnome-extra

9) arch-chroot /mnt (don't exit chroot until the last step)
10) echo "\<computer name\>" > /etc/hostname (this will appear at your default shell prompt)
11) echo -e "127.0.0.1\tlocalhost\n      ::1\tlocalhost" >> /etc/hosts
12) (do it if any or all lines are commented) vim /etc/pacman.d/mirrorlist or /etc/pacman.d/mirrorlist.pacnew (whichever file exists) <Esc> key :%s/"# Server"/"Server"/g <Esc> key :wq
13) service enable --now NetworkManager
14) useradd -m <username> -G wheel,power,storage -g users
15) passwd <username> (set password for username)
16) passwd (set root password)
17) grub-install --verbose --boot-directory=/boot/grub --bootloader-id="NAME" --efi-directory=/boot/ --target="\<your cpu architecture\>" (target section of grub-install --help)
18) grub-mkconfig -o /boot/grub/grub.cfg
19) genfstab -U / > /etc/fstab (if genfstab doesnt exist then exit chroot and execute genfstab)
21) reboot and remove the usb drive
