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
6) pacman -Sy
7) (base systems) pacstrap /mnt/ base base-devel devel linux linux-{headers,docs} networkmanager iw net-tools dkms broadcom-wl-dkms vim pulseaudio efi{var,bootmgr} grub sudo os-prober
8) (optional. can be done after installation as well but on live use pacstrap) install a Desktop environment or window manager and a soundmanager.
9) arch-chroot /mnt
10) echo "<computer name>" > /etc/hostname (this will appear at your default shell prompt)
11) echo -e "127.0.0.1\tlocalhost\n      ::1\tlocalhost" > /etc/hosts
12) (do it if all lines are commented) vim /etc/pacman.d/mirrorlist or /etc/pacman.d/mirrorlist.pacnew (whichever file exists) <Esc> key :%s/"# Server"/"Server"/g <Esc> key :wq
13) service enable --now NetworkManager
14) useradd -m <username> -G wheel,power,storage -g users
15) passwd <username> (set password for username)
16) passwd (set root password)
17) grub-install --verbose --boot-directory=/boot/grub --bootloader-id="NAME" --efi-directory=/boot/ --target="<your cpu architecture>" (target section of grub-install --help)
18) grub-mkconfig -o /boot/grub/grub.cfg
19) genfstab / > /etc/fstab (if genfstab doesnt exist then exit chroot and execute genfstab)
21) reboot and remove the usb drive

