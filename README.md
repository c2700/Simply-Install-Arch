The Installer will install only on EFI systems. (will install arch only on x86_64 architecture for now)<br>
Run from live ISO - Runs as Installer<br>Run from installed system - Runs as host setup script (Installation options will not show up)
<br><br>
<h2> To run the installer </h2><br>
cd Simply-Install-Arch<br>
chmod a+x Arch\ Installer.sh<br>
./Arch\ Installer.sh<br><br>

<br>As a heads up if you have rewritten the partition table (through the installer i.e.) and find mismatched partition information, don't worry about it. Manually wipe it using "wipefs -a" on the disk you want to wipe and partition it again but few partitions are of the same size and block order as the previous partitions then those partitions would have the same filesystem as it had before the wipe. "wipefs -a" the disk you want to wipe, partition the disk with few partitions of the same size and block partition order as before the wipe, lsblk the disk you wiped and partitioned and see for yourself.

Just Run the script and go through the options. Also, when inserting a new disk you don't need to exit the script to let your newly inserted disk to show up in the disk menu. Just wait for a second or two and select the "Partition Disk\*\*" menu item to see the disk in the "Disk Selection Menu" And If you insert a disk when in the "Disk Selection Menu" just go back to the Main Menu and select "Partition Disk\*\*" Menu item<br><br><br>
Plz Don't judge me for my horrible and confusing variable names and naming convention if you plan on reading the script 👀. It's something I came up with on the spot and only had a vague idea on how the script should behave.<br><br><br>

## <H1>To Add</H1>

<h3>1. Auto-Install Menu:</h3>

- [ ] Fresh Auto Install
- [ ] MultiBoot Auto Install

<br><h3>2. Bootloaders:</h3>

- [ ] syslinux
- [ ] refind
- [ ] systemd-boot (bootctl)

<br><h3>3. shell rc files:</h3>
   
- [ ] bashrc prompts for stronger machines (A mix of conf files, python scripts, bash scripts just to make it look like those prompts you see with git icons and colorfilled text embeded arrows. not advisable to be used on weak machines though it can be used)
- [ ] zshrc prompts as the one above.

<br><h3>4. partition editor:</h3>
   
- [ ] include manual editing on the dialog iface (parted will be used to partition the disk)
- [ ] include auto partition

<br><h3>5. autoset timezone:</h3>
   
- [ ] set default locale as english based on the tz selected if locale is not set. If tz (and/or) locale is not selected then prompt to select tz first (if not selected) then prompt for locale selection
