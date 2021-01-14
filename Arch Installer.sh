#!/bin/bash

DIALOG_OK=1
DIALOG_CANCEL=0
DIALOG_ESC=255
DIALOG_HELP=2
DIALOG_HELP_ITEM_HELP=2
DIALOG_EXTRA=3

# 3>&1 1>&2 2>&3
GuageMeter(){
	# $1 - guagebox text
	# $2 - number
	# $3 - $?
 	c=0
	while [ $c -le 100 ]
	    do
	        echo "###"
			echo $c
			echo "### $c%"
			((c+=$2))
	        ((c+=1))
	done | dialog --gauge "${1}" 0 0 0
	# ) | dialog --gauge "${1}" 0 0 0
}

# Network Mgmnt

iw_reconnect(){
	# $1 - $?
	# $2 - $wireless_dev
	# $3 - $SSID
	# $4 - $pass
	if [[ "${1}" -eq 1 ]]
	then
		dialog --yesno "rescan and connect to a wireless device? " 0 0
		while read -n1 -p "line: " line
		do
			if [[ $line == "y" ]]
			then
				if [[ -z "${4}" ]]
				then
					iwctl station "${2}" connect "${3}"
				else
					iwctl --passphrase "${4}" station "${2}" connect "${3}"
				fi
			elif [[ $line == "n" ]]
			then
				dialog --yesno "use a different network manager?" 0 0
				if [[ $? -eq 1 ]]
				then
					iwd_mngr
				elif [[ $? -eq 0 ]]
				then
					ConfNet
				fi
			fi
		done
	fi
}

iwd_mngr(){
	systemctl enable iwd
	systemctl start iwd

	#select wireless card
	wireless_devs=($(iwctl station list | grep -iv 'name\|devices\|\-' | awk '{print $1}'))
	if [[ ${#wireless_devs[@]} -eq 1 ]]
	then
		wireless_card="${wireless_devs[@]}"
	else
		wireless_cards=()
		for i in "${wireless_devs[@]}"
		do
			wireless_cards+=("$i")
			wireless_cards+=("")
		done
		wireless_dev=$(dialog --menu "Wireless Card Selection Menu" 0 0 0 "${wireless_cards[@]}" 3>&1 1>&2 2>&3)
	fi

	clear
	iwctl station "$wireless_dev" scan
	clear
	iwctl station "$wireless_dev" get-networks | more && read -p "Enter Wireless network to connect to : " SSID
	dialog --yesno "view wireless passphrase in plaintext as you enter?" 0 0
	if [[ $? -eq 0 ]]
	then
		# read -p "$SSID password: " pass
		iwctl --passphrase $pass station $wireless_dev connect $SSID
		iw_reconnect $? $wireless_dev $SSID "$(read -p "$SSID password: ")"
	else
		iwctl station $wireless_dev connect $SSID
		iw_reconnect $? $wireless_dev $SSID
	fi
}


nm_mngr(){
	systemctl enable NetworkManager
	systemctl start NetworkManager
	nmcli networking on
	nmcli radio wifi on
	if [[ $? -eq 1 ]]
	then
		con_name=$(dialog --inputbox "set a name for this wired connection" 0 0 3>&1 1>&2 2>&3)
		nmcli connection add con-name "$con_name" type ethernet autoconnect yes
	else
		nmcli device wifi rescan
		clear
		dialog --msgbox "press 'q' to exit the upcoming wifi list" 0 0
		nmcli device wifi list && read -p "Enter SSID to connect to: " wifi_name
		nmcli device wifi connect $wifi_name -a
		if [[ $? -eq 1 ]]
		then
			# for (( reconnect = "n"; reconnect != "n" ;))
			for (( reconnect = "n"; reconnect -eq "y" ;))
			do
				nmcli device wifi list && read -p "Enter SSID to connect to: " wifi_name
				nmcli device wifi connect $wifi_name -a
				read -p "rescan and connect to another ssid? [y/n]" reconnect
			done
		fi
	fi
}



ConfNet(){
	# pacman -Syvd --noconfirm --needed
	# ping -c4 google.com | GuageMeter "Checking for network availablity" 25
	ping -c4 google.com &>/dev/null | GuageMeter "Checking for network availablity" 1
	if [[ ${PIPESTATUS[0]} -eq 0 ]]
	then
		dialog --title "Installed Network Manager" --msgbox "network available" 0 0
		MainMenu "Configure Network *"
	else
		dialog --title "Network Status" --msgbox "network not available. will search for availble network managers" 0 0
	fi

	NMList=()
	: '
	for i in "wifi-menu" "networkmanager" "iwd"
	do
		pacman -Qqs ^"$i"$ &>/dev/null | GuageMeter "Checking if ${i} is available" 20
		if [[ $? -eq 0 ]]
		then
		# if [[ ${PIPESTATUS[0]} -eq 0 ]]
		then
			NMList+=("$i")
			NMList+=("")
			# NM="$i"
		else
			continue
		fi
	done
	'
	ls /bin/wifi-menu &>/dev/null
	if [[ $? -eq 0 ]]
	then
		NMList+=("wifi-menu")
		NMList+=("")
	fi
	ls /usr/lib/systemd/system/NetworkManager* &>/dev/null
	if [[ $? -eq 0 ]]
	then
		NMList+=("networkmanager")
		NMList+=("")
	fi

	ls /usr/lib/systemd/system/iwd* &>/dev/null
	if [[ $? -eq 0 ]]
	then
		NMList+=("iwd")
		NMList+=("")
	fi

	if [[ ${#NMList[@]} -eq 0 ]]
	then
		dialog --msgbox "no networkmanagers available" 0 0
		dialog --msgbox "networkmanager will be installed" 0 0
		MainMenu "Configure Network"
		# pacman -Syvd --noconfirm --needed networkmanager
		nm_mngr
	fi

	NM=$(dialog --cancel-label "BACK" --menu "Availble Network Managers" 0 0 0  "${NMList[@]}" 3>&1 1>&2 2>&3)

	if [[ $? -eq 255 ]]
	then
		ConfNet
	fi

	case $NM in
		"wifi-menu")
			# "${NM}"
			wifi-menu
			;;
		"networkmanager")
			# nm_mngr
			dialog --msgbox "networkmanager used" 0 0
			MainMenu "Configure Network *"
			;;
		"iwd")
			# iwd_mngr
			dialog --msgbox "iwd used" 0 0
			MainMenu "Configure Network *"
			;;
		*)
			MainMenu "Configure Network *"
			;;
	esac
}



# UI
Install_UI(){
	# Install_UI
	# ConfHost
	# $1 - options in this function's menu
	# $2=""

	pkgs=""

	ui_opts=()
	ui_opts+=("Window Manager")
	ui_opts+=("Just windows and statusbars (minimal).No Graphics composition like on Gnome")
	ui_opts+=("Desktop Environment")
	ui_opts+=("Gnome, KDE, cinnamon and stuff like that")

	UI=$(dialog --cancel-label "BACK" --default-item "${1}" --menu "UI Menu" 0 0 0 "${ui_opts[@]}" 3>&1 1>&2 2>&3)
	if [[ $? -eq 1 ]]
	then
		ConfHost "Install UI"
	fi

	wmopts=()
	wmopts+=("i3" "")
	wmopts+=("bspwm" "")
	wmopts+=("awesome" "")

	deopts=()
	deopts+=("KDE" "")
	deopts+=("Gnome" "")
	deopts+=("cinnamon" "")
	deopts+=("deepin" "")
	deopts+=("lxde" "")
	deopts+=("lxqt" "")
	deopts+=("mate" "")
	deopts+=("Unity" "")

	case $UI in
		"Desktop Environment")
			DE=$(dialog --cancel-label "BACK" --menu "Desktop Environment Menu" 0 0 0 "${deopts[@]}" 3>&1 1>&2 2>&3)
			if [[ $? -eq 1 ]]
			then
				Install_UI "Desktop Environment"
			fi
			case $DE in
				"KDE")
					pkgs="$(pacman -Sg plasma kde-{applications,system,graphics,network,accessibility} kf{5,5-aids} | awk '{print $2}' | uniq)"
					;;
				"Gnome")
					pkgs="gnome gnome-extra"
					;;
				"cinnamon")
					pkgs="$(pacman -Ssq cinnamon)"
					;;
				"deepin")
					pkgs="deepi{n,n-extra}"
					;;
				"lxde")
					pkgs="lxd{e,e-gtk3}"
					;;
				"lxqt")
					pkgs="lxqt"
					;;
				"mate")
					pkgs="mat{e,e-extra}"
					;;
				*)
					dialog --msgbox "no DE installed"
					Install_UI "Desktop Environment"
					;;
			esac
			;;
		"Window Manager")
			WM=$(dialog --cancel-label "BACK" --menu "Window Manager Menu" 0 0 0 "${wmopts[@]}"  3>&1 1>&2 2>&3)
			if [[ $? -eq 1 ]]
			then
				Install_UI "Window Manager"
			fi
				case $WM in
					"i3")
						pkgs=$(pacman -Ssq i3 | grep -iv 'py\|7\|perl\|sway')
						;;
					"bspwm")
						pkgs="bspwm"
						;;
					"awesome")
						pkgs="awesom{e,e-terminal-fonts} vicious powerline "
						;;
					*)
						dialog --msgbox "no window managers available"
				esac
			;;
		*)
			dialog --menu "SIKE" 0 0
			;;
	esac
	dialog --msgbox "$pkgs" 0 0
	# pacstrap $2 $pkgs
	ConfHost "Install UI"
}













SetTz(){
	# $1 - default option
	regions=()
	regions_dir_temp=($(ls -d /usr/share/zoneinfo/* | grep -iv 'right\|posix\|\.[a-zA-Z0-9]*'))
	regions_temp=($(ls /usr/share/zoneinfo/ | grep -iv 'right\|posix\|\.[a-zA-Z0-9]*'))

	a=0
	for b in "${regions_dir_temp[@]}"
	do
		if [[ -d "$b" ]]
		then
			regions+=("$b")
			regions+=("${regions_temp[$a]}")
		fi
		((a+=1))
	done

	# unset regions_temp regions_dir_temp
	region=$(dialog --cancel-label "Back" --no-tags --menu "select the continent you are in" 0 0 0 "${regions[@]}" 3>&1 1>&2 2>&3)
	if [[ $? -eq 1 ]]
	then
		ConfHost "set timezone"
	else
		a=0
		zones=()
		zones_temp=($(ls $region))
		zones_temp_dir=($(ls -d $region/*))

		for b in "${zones_temp_dir[@]}"
		do
			if [[ -f "$b" ]] && [[ -r "$b" ]]
			then
				zones+=($b)
				zones+=(${zones_temp[$a]})
			fi
			((a+=1))
		done
		zone=$(dialog --cancel-label "back" --no-tags --menu "select the region you are in" 0 0 0 "${zones[@]}" 3>&1 1>&2 2>&3)
		if [[ $? -eq 1 ]]
		then
			SetTz
		else
			: '
			ln -sf $zone /mnt/etc/localtime &>/dev/null
			arch-chroot /mnt/ hwclock -wrv | dialog --programbox 0 0
			if [[ ${PIPESTATUS[0]} -eq 0 ]]
			then
			'
				dialog --msgbox "timezone is set ${zone}" 0 0
			# fi
		fi
	fi
}




SetLocale(){

	# user set locale
	# $1 - arch-root dir
	LOCALE=()
	# cat "${1}/etc/locale.gen" | grep -i '#\w' | sed 's/#//' > locales.txt
	# cat "/mnt/etc/locale.gen" | grep -i '#\w' | sed 's/#//' > locales.txt
	cat "/etc/locale.gen" | grep -i '#\w' | sed 's/#//' > locales.txt
	# cat "/mnt/etc/locale.gen" | grep -i '#\w' | sed 's/#//' > locales.txt

	dialog --msgbox "when you press a character and you don't see the character, just keep that charcter held until you see the cursor" 0 0

	while read txt
	do
		LOCALE+=("${txt}")
		LOCALE+=("${txt}")
		LOCALE+=(OFF)
	done < locales.txt

	rm -rf locales.txt
	# back - 1
	# ok - 0
	LocaleDialog=$(dialog --scrollbar --visit-items --cancel-label "BACK" --title "Locale Selection Menu" --buildlist "\nUse the space bar to move locale options between the panes and use the tab for moving in between spacess. If no locale is selected then the deafult UTF-8 and ISO-8859 versions of the US english locales will be set \n\n       disabled locales                                      enabled locales" 0 0 0 "${LOCALE[@]}" 3>&1 1>&2 2>&3)

	echo "${LocaleDialog[@]}" | sed 's/" "/"\n"/g;s/"//g' > locales.txt
	while read txt
	do
		# arch-chroot /mnt sed -i s/"#$txt"/"$txt"/g /etc/locale.gen
		# arch-chroot /mnt locale-gen
		sed -i s/"#$txt"/"$txt"/g locale.gen
		# awk '{print ARGV}'
	done < locales.txt
	# nicepl=("$(cat locales.txt)")
	# echo -e "locales\n${nicepl[*]}" | sed 's/"\n"//g'
	LocaleFormat=$(echo -e "\n\n${LocaleDialog[@]}\n" | sed 's/" "/"\n"/g')
	dialog --msgbox "locales set:$LocaleFormat" 0 0
	# locale-gen
	# rm -rfv locales.txt &2>/dev/null


	: '
	$? - 2 - help
	$? - 1 - cancel
	$? - 0 - ok
	'
}



SetHostName(){
	hostname=$(dialog --inputbox "Set host name" 0 0 3>&1 1>&2 2>&3)
	if [[ -z $hostname ]]
	then
		dialog --yesno "Default name 'arch' will be assigned as hostname. continue?" 0 0
		if [[ $? -eq 0 ]]
		then
			hostname="arch"
		else
			SetHostName
		fi
	fi
	# arch-chroot /mnt echo "$hostname" > "/mnt/etc/hostname"
	dialog --msgbox "set $hostname as hostname. You can change the hostname in the /etc/hostname file in the arch-chroot directory" 0 0
	# arch-chroot /mnt echo -e "127.0.0.1\tlocalhost\n      ::1\tlocalhost" > "/mnt/etc/hostname"
}

SetPassword(){
	NewPassword=$(dialog --passwordbox "set password for username $username" 0 0 3>&1 1>&2 2>&3)
	if [[ $? -eq 1 ]]
	then
		# ConfHost "add users"
		add_users
	else
		if [[ ${#NewPassword} -eq 0 ]]
		# if [[ -z ${NewPassword} ]]
		then
			dialog --yesno "Accounts without passwords is as good as an inaccessible account (i.e. if the passwordless account is the only non-root account you have created). linux will prompt you for a password regardless of password state on an account/username.\nYou can login into the passwordless account by doing one, select few or all of the following\n1) logging in with an account that contains a password (if you have created one i.e.) and then logging in with the 'passwordless account' from the currently active account\n2) logging in as root and then loggin in with the 'passwordless account'.\n3) going to line 79 of /etc/sudoers and adding '<passwordless account name> ALL=(ALL) NOPASSWD: ALL'\n\nAll the above is as per my experience.\nProceed setting the passwordless account regardless?" 0 0
			if [[ $? -eq 1 ]]
			then
				SetPassword
			else
				password=$NewPassword
			fi
		else
			if [[ ${#NewPassword} -lt 8 ]] && [[ ${#NewPassword} -gt 0 ]]
			then
				dialog --msgbox "password need to be atleast 8 characters long" 0 0
				SetPassword
			elif [[ ${#NewPassword} -ge 8 ]]
			then
				ConfirmPassword=$(dialog --passwordbox "Confirm password for username $username" 0 0 3>&1 1>&2 2>&3)
				if [[ $ConfirmPassword == $NewPassword ]]
				then
					password=$NewPassword
				elif [[ "$ConfirmPassword" != "$NewPassword" ]]
				then
					dialog --msgbox "passwords do not match" 0 0
					SetPassword
				fi
			fi
		fi
	fi
}

add_users(){
	password=""
	username=$(dialog --inputbox "Username" 0 0 3>&1 1>&2 2>&3)
	if [[ $? -eq 1 ]]
	then
		ConfHost "add users *"
	fi

	if [[ ${#username} -eq 0 ]]
	then
		dialog --msgbox "username cannot be an empty string" 0 0
		add_users
	else
		dialog --msgbox "you won't see the password characters as they are typed" 0 0
		SetPassword
	fi

	# dialog --msgbox "created username ${username} and password ${password} is set" 0 0
	dialog --msgbox "created username ${username} and password is set" 0 0
	# arch-chroot /mnt useradd -m $username -G users -g power,wheel,storage &>/dev/null
	# arch-chroot /mnt passwd $username &>/dev/null
	# if [[ $? -eq 2 ]]
	# then
	# 	dialog --msgbox "user ${username} exists"
	# 	add_users
	# fi
}

BashPromptPreview(){
	# $1 - bash prompt
	clear
	mv /root/.bashrc /root/.bashrc.bak &>/dev/null
	cp -rfv bashrc/$1 /root/.bashrc &>/dev/null
	bash
	rm -rfv /root/.bashrc &>/dev/null
	mv /root/.bashrc.bak /root/.bashrc &>/dev/null
}

SetPrompt(){
	# $1 - bashrc file

	Users=($(grep [1-9][0-9][0-9][0-9] /mnt/etc/passwd | grep -iv nobody | sed 's/\:/ \: /g' | awk '{print $1}'))
	# cp -rfv bashrc/"$1" /mnt/home/$Users/.bashrc &>/dev/null
	# cp -rfv bashrc/"$1" /mnt/home/$Users/.bashrc &>/dev/null
	cp -rfv bashrc/"$1" /home/$Users/.bashrc &>/dev/null
	dialog --msgbox "set $1 as the bash prompt" 0 0
}

SetBashPrompt(){
	# $1 - "menu option item"

	bashrc_opts=("default" "it's the same as you see on the live iso")
	bashrc_opts+=("modded parrot" "my personalized version of the parrot OS bash prompt")
	bashrc_opts+=("parrot" "bash prompt taken from parrot OS")
	bashrc_opts+=("pop OS" "pop OS bash prompt")
	# bashrc_opts+=()
	Users=($(grep [1-9][0-9][0-9][0-9] /etc/passwd | grep -iv nobody | sed 's/\:/ \: /g' | awk '{print $1}'))

	# exit code references
	# 0 - ok
	# 3 - preview
	# 1 - back

	$1="${bashrc_opts[0]}"
	bashrc=$(dialog --ok-label "set bashrc" --default-item "$1" --extra-button --extra-label "preview" --cancel-label "back" --menu "bashrc selection menu\n\nselected menuitem will be saved as \".bashrc\" in the home directory" 0 0 0 "${bashrc_opts[@]}" 3>&1 1>&2 2>&3)

	if [[ $? -eq 3 ]]
	then
		dialog --msgbox "you will enter a subshell. execute \"exit\" to exit to the installer" 0 0
		case $bashrc in
			'default')
				BashPromptPreview default_bashrc
				SetBashPrompt "deafult"
				;;

			'modded parrot')
				BashPromptPreview modded_parrot_bashrc
				SetBashPrompt "modded parrot"
				;;

			'parrot')
				BashPromptPreview parrot_bashrc
				SetBashPrompt "parrot"
				;;

			'pop OS')
				BashPromptPreview bashrc_pop
				SetBashPrompt "pop OS"
				;;
		esac

	elif [[ $? -eq 0 ]]
	then
		case $bashrc in
			'default')
				SetPrompt default_bashrc
				SetBashPrompt "deafult"
				;;

			'modded parrot')
				SetPrompt modded_parrot_bashrc
				SetBashPrompt "modded parrot"
				;;

			'parrot')
				SetPrompt parrot_bashrc
				SetBashPrompt "parrot"
				;;

			'pop OS')
				SetPrompt bashrc_pop
				SetBashPrompt "pop OS"
				;;
		esac
	fi
}

SetRootPassword(){
	RootPassword=$(dialog --no-cancel --passwordbox "Enter root password. Default root password is 'password'. if default password is set please change the default root password post installation as it can be cracked through rainbow tables, dictionary or brute force attacks" 0 0 3>&1 1>&2 2>&3)
	if [[ -z $RootPassword ]]
	then
		RootPassword="password"
		# arch-chroot "echo $RootPassword;echo $RootPassword" | passwd &>/dev/null
		dialog --msgbox "default root password 'password' is set " 0 0
	else
		ConirmRootPassword=$(dialog --passwordbox "confirm root password" 0 0 3>&1 1>&2 2>&3)
		if [[ $RootPassword != $ConfirmPassword ]]
		then
			dialog --msgbox "root password does not match" 0 0
			SetRootPassword
		elif [[ $RootPassword == $ConfirmPassword ]]
		then
			dialog --msgbox "root password is set" 0 0
			# arch-chroot "echo $RootPassword;echo $RootPassword" | passwd &>/dev/null
		fi
	fi
}

ConfHost(){
	# $1 - menu option item
	# if [[ -z $1 ]]

    # need to give a different condition to reassure mnt. pt.
	# if [[ -z $2 ]]
	# then
	# 	dialog "mount the partitions" 0 0
	# 	MainMenu "Configure Host *"
	# fi
	# HostOpt=()
	HostOpt=("set hostname *" "set your computer name")
	HostOpt+=("set Locale *" "set your computer language")
	HostOpt+=("set timezone" "configure which timezone you are in")
	HostOpt+=("add users *" "add users")
	HostOpt+=("root password *" "set root password")
	HostOpt+=("Install UI" "Install Desktop Environment or Window Manager")
	HostOpt+=("Set Bash Prompt" "File that's used to tell how the terminal prompt should look like")
	$1="${HostOpt[0]}"
	opt=$(dialog --cancel-label "BACK" --default-item "${1}" --menu "Host Configuration Menu" 0 0 0 "${HostOpt[@]}" 3>&1 1>&2 2>&3)
	if [[ $? -eq 1 ]]
	then
		MainMenu "Configure Host *"
	fi
	case $opt in
		"set hostname *")
			SetHostName
			ConfHost "set hostname *"
			;;
		"set Locale *")
			SetLocale
			ConfHost "set Locale *"
			;;
		"set timezone")
			SetTz
			ConfHost "set timezone"
			;;
		"add users *")
			add_users
			ConfHost "add users *"
			;;
		# "set root password")
		"root password *")
			dialog --msgbox "you won't see the characters as you type" 0 0
			SetRootPassword && ConfHost "set root password"
			;;
		"Install UI")
			Install_UI "Window Manager"
			ConfHost "Install UI"
			;;
		"Set Bash Prompt")
			SetBashPrompt
			ConfHost "Set Bash Prompt"
			;;
		*)
			dialog --msgbox "sike" 0 0
			ConfHost "root password *"
			;;
	esac
}






DiskListTemp(){
	lsblk -dno name,size,pttype,vendor,model | grep -iv 'loop\|sr0'
}

DiskPartInfoTemp(){
    lsblk -nlo name,size,fstype,fsver,parttypename /dev/"$1" | grep -i '[a,s]d[a-z][0-9]' | grep -i 'ext4\|fat32\|vfat\|efi\|swap' | sed 's/1.0   //g;s/vfat   FAT32 EFI System/FAT32  EFI System/g;s/swap   1     Linux swap/swap   Linux swap/g'
    echo -e "\n"
}

PartitionDisk(){
	# 3>&1 1>&2 2>&3
	DiskList=($(DiskListTemp | awk '{print $1}'))
	DiskSize=($(DiskListTemp | awk '{print $2}'))
	DiskPartTable=($(DiskListTemp | awk '{print $3}'))
	DiskVendor=($(DiskListTemp | awk '{print $4}'))
	DiskModel=($(DiskListTemp | awk '{print $5}'))

	DiskListInfo=()
	DiskName=()

	for (( i = 0; i <= ${#DiskList}; i++ ))
	do
		DiskName+=("${DiskVendor[$i]} ${DiskModel[$i]}")
	done

	for (( i = 0; i < ${#DiskList[@]}; i++ ))
	do
		if [[ -z ${DiskPartTable[$i]} ]] && [[ -z ${DiskSize[$i]} ]] && [[ -z ${DiskName[$i]} ]]
		then
            continue
        else
            DiskListInfo+=("${DiskList[$i]}")
			DiskListInfo+=("${DiskPartTable[$i]} | ${DiskSize[$i]} | ${DiskName[$i]}")
			DiskListInfo+=(0)
		fi
	done
    # clear
    # echo "${DiskListInfo[@]}"
    # sleep 2
	Disks=($(dialog --scrollbar --cancel-label "Back" --column-separator "|" --title "Disk Selection Menu" --checklist "" 0 0 0 "${DiskListInfo[@]}" 3>&1 1>&2 2>&3))


	if [[ $? -eq 0 ]]; then
		if [[ -z ${Disks[@]} ]]; then
			dialog --msgbox "please select atleast one disk" 0 0
			PartitionDisk
		else
			dialog --yes-label "Mount" --no-label "Edit" --yesno "Select \"Edit\" for Editing and then mounting the partitions of this disk or select \"Mount\" to only select and mount existing ext4/efi/fat32/swap partitions" 0 0


			if [[ $? -eq 0 ]]; then
				DiskPartListInfo=()
                DiskPartNameTemp=()
                DiskPartSizeTemp=()

                clear
                for ((a = 0; a < ${#Disks[@]}; a++))
                do
                    DiskPartNameTemp=($(DiskPartInfoTemp "${Disks[$a]}" | awk '{ print $1 }'))

                    DiskPartSizeTemp=($(DiskPartInfoTemp "${Disks[$a]}" | awk '{ print $2 }'))

                    DiskPartFsTypeTemp=($(DiskPartInfoTemp "${Disks[$a]}" | awk '{ print $3 }'))

                    DiskPartPartTypeTempString1=($(DiskPartInfoTemp "${Disks[$a]}" | awk '{ print $4 }'))

                    DiskPartPartTypeTempString2=($(DiskPartInfoTemp "${Disks[$a]}" | awk '{ print $5 }'))

                    if [[ -z ${DiskPartSizeTemp[@]} ]] && [[ -z ${DiskPartFsTypeTemp[@]} ]] && [[ -z ${DiskPartPartTypeTempString1[@]} ]] && [[ -z ${DiskPartPartTypeTempString2[@]} ]]
                    then
                        continue
                    else
                        for (( b = 0; b < ${#DiskPartNameTemp[@]}; b++ ))
                        do
                            DiskPartPartTypeTemp="${DiskPartPartTypeTempString1[$b]} ${DiskPartPartTypeTempString2[$b]}"

                            DiskPartInfo="${DiskPartSizeTemp[$b]} | ${DiskPartFsTypeTemp[$b]} | $DiskPartPartTypeTemp"

                            DiskPartListInfo+=("${DiskPartNameTemp[$b]}")
                            DiskPartListInfo+=("$DiskPartInfo")

                        done
                        dialog --cancel-label "Back" --column-separator "|" --title "Partition mount menu"  --menu "Partitions in /dev/${Disks[$a]}" 0 0 0 "${DiskPartListInfo[@]}"
                        unset DiskPartListInfo
                    fi

                done

			else
				PartTools=("fdisk" "fdisk")
				PartTools+=("gdisk" "gdisk")
				PartTools+=("cgdisk" "cgdisk")
				PartTools+=("cfdisk" "cfdisk")
				PartTools+=("sfdisk" "sfdisk")

				PartTool=$(dialog --no-tags --menu "Partition Tool Selection Menu" 0 0 0 "${PartTools[@]}" 3>&1 1>&2 2>&3)

				for i in ${Disks[@]}
				do
					dialog --msgbox "editing $i using $PartTool" 0 0
					clear
					case $PartTool in
						'fdisk')
							fdisk /dev/$i
							;;
						'gdisk')
							gdisk /dev/$i
							;;
						'cgdisk')
							cgdisk /dev/$i
							;;
						'cfdisk')
							cfdisk /dev/$i
							;;
						'sfdisk')
							sfdisk /dev/$i
							;;
					esac
				done

			fi
		fi
	elif [[ $? -eq 1 ]]; then
		MainMenu "Partition Disk *"
	fi
}

	# dialog --yes-label "Mount" --no-label "Edit" --yesno "Select Mount to only mount the partition in the /mnt directory. Select Edit to edit and mount the partition" 0 0































MainMenu(){
	# $1 - menu option item

	menuopt=("Partition Disk *" "format, Partition or select the Hard Disk and mount the hard disk partitions")
	menuopt+=("Configure Network *" "Connect to Network")
	menuopt+=("Install Arch *" "Install the base system")
	menuopt+=("Configure Host *" "Personalize the machine by setting Hostname, adding users etc.")
	menuopt+=("continue Live" "Continue having A feel for the OS")
	menuopt+=("Reboot" "Reboot the computer")

	# $1="Manual Install"
	if pacman -Qs $dialog > /dev/null ; then
		$1="${menuopt[0]}"
	else
		echo "Please install dialog on your machine!"
		exit
	fi

	menuitem=$(dialog --default-item "${1}" --backtitle "Written by c2700" --cancel-label "Exit" --title "Install Menu" --menu "To install arch all options followed by '*' are mandatory" 0 0 0 "${menuopt[@]}" 3>&1 1>&2 2>&3)

	if [[ $? -eq 1 ]]
	then
		clear;reset;exit
	fi

	case $menuitem in
		"Partition Disk *")
			PartitionDisk
			# MainMenu "Partition Disk *"
			;;
		"Configure Network *")
			# dialog --msgbox "Configure Network" 0 0
			ConfNet
			if [[ $? -eq 1 ]]
			then
				MainMenu "Configure Network *"
			fi
			;;

		"Install Arch *")

            # make another condition that ensures something is mounted in the /mnt dir. this one seems senseless now that I read it

			# archchrootdir='/mnt'
			archchrootdir=''
			# if [[ $archchrootdir == '' ]]
			if [[ -z $archchrootdir ]]
			then
				dialog --msgbox "arch chroot directory not mentioned" 0 0
				MainMenu "Install Arch *"
			else

				# nvidia linux nvlink/capabilities/fabric-mgmt 0

				packages="base base-devel devel linu{x,x-{docs,headers}} grub efi{var,bootmgr} dkms broadcom-dkms-wl-dkms xf86-input-{libinput,synaptics} xf86-video-fbdev"

				cpu_vendor=$(cat /proc/cpuinfo | grep vendor | uniq | awk '{print $3}')

				amd_gpu="xf86-video-{amdgpu,ati} lib32-{amdvlk,opencl-mesa} opencl-mesa amdvlk"

				intel_gpu="xf86-video-intel libva-intel-driver lib32-{libva-intel-driver,vulkan-intel} vulkan-intel intel-graphics-compiler"

				nvidia_gpu="ffnvcodec-headers libvdpau opencl-nvidia xf86-video-nouveau lib32-{libvdpau,nvidia-utils,opencl-nvidia} nvidia-{dkms,lts,prime,settings,utils}"


				# dialog --checklist "terminal text editors"
				if [[ $cpu_vendor == "AuthenticAMD" ]]
				then
					packages="$packages amd-ucode"
				elif [[ $cpu_vendor == "GenuineIntel" ]]
				then
					packages="$packages intel-ucode tbb intel-undervolt throttled"
				fi
				terminaleditorslist=("vim" "vim" off)
				terminaleditorslist+=("neovim" "neovim" off)
				terminaleditorslist+=("emacs" "emacs" off)
				terminaleditorslist+=("joe" "joe" off)
				terminaleditorslist+=("nedit" "nedit" off)
				terminaleditorslist+=("kakoune" "kakoune" off)
				terminaleditorslist+=("zile" "zile" off)
				terminaleditorslist+=("mg" "mg micro emacs" off)

				editors=($(dialog --extra-button --extra-label "Cancel" --cancel-label "Back" --no-tags --title "text editor selection Menu" --checklist "nano and vi will be installed by default" 0 0 0 "${terminaleditorslist[@]}" 3>&1 1>&2 2>&3))

				if [[ $? -eq 0 ]]
				then
					# editors="${editors[@]}"
					if [[ $editors == "" ]]
					then
						packages="${packages}"
					else
						packages="${packages} ${editors[@]}"
					fi
				fi

				if [[ $? -eq 3 ]]
				then
					packages="${packages}"
					# break
				fi

				if [[ $? -eq 1 ]]
				then
					MainMenu "Install Arch *"
				fi

				dialog --msgbox "packages that will be installed:\n${packages}" 0 0

				: '
				pacstrap /mnt "$packages" | GuageMeter "Installing arch linux packages" 1
				# pacstrap /mnt "$packages"
				if [[ ${PIPESTATUS[0]} -eq 0 ]]
				then
					genfstab "/mnt/" > "/mnt/etc/fstab"
				else
					dialog --msgbox "failed to install packages via pacstrap"
				fi
				'
				dialog --msgbox "Created fstab entry. you can generate the fstab of your disk by executing genfstab -U {arch-chroot directory} (in this case it's the /mnt directory) > {arch-chroot directory}/etc/fstab' (i.e. if anythin went wrong with the fstab entry)" 0 0
				MainMenu "Install Arch *"
			fi
			;;


		"Configure Host *")
			: '
			arch-chroot /mnt
			if [[ $? -eq 1 ]]
			then
				dialog --msgbox "cannot chroot" 0 0
			else
			'
				ConfHost "set hostname *"
			# fi
			MainMenu "Configure Host *"
			;;

		"continue Live")
			exit
			clear
			reset
			;;
		"Reboot")
			dialog --extra-button --extra-label "cancel" --msgbox "Reboot the machine" 0 0
			if [[ $? -eq 3 ]]
			then
				MainMenu "Reboot"
			else
				dialog --yesno "save basic customization instructions in the arch partition? It will be stored in the /home/customize.txt file of your arch install location. use less, more, cat or a text editor to view the file" 0 0
				if [[ $? -eq 1 ]]
				then
					dialog --msgbox "saved basic customization instructions" 0 0
					# echo -e "change hostname - vim /etc/hostname\ncreate users - useradd -m\n<username> -G power,storage,wheel -g users\nset or change user password - passwd <username>\nset or change user password - passwd\nset locale - vim /etc/locale.gen, comment '#' to ignore and uncomment to generate or use the locale\n\n(DE - Desktop Environment, WM - Window Manager) to install a DE - install a minimal DE package or the group using the '-g' argument in pacman and a lockscreen manager. enable the lockscreen manager using the systemctl tool and write the DE session name in the /home/<user name>/.xinitrc file\n to install a WM - install a WM and the lockscreen manager will pick it up (if enabled)\nset timezone - soft link (ln -sf) /usr/share/zoneinfo/<continent>/<region> /etc/localtime execute hwclock -w -v (-v is optional if you prefer verbosity)" > /mnt/home/customize.txt
				fi
			fi
			# reboot now -f
			clear;reset
			;;
		*)
			dialog --msgbox "sike" 0 0

			MainMenu "Reboot"
			;;
	esac

}


# uncomment repos excluding testing repos
# sed '94s/\#\[/"["' /etc/pacman.conf
# sed '95s/\#\[/""' /etc/pacman.conf
# dialog --backtitle "Written by c2700" --msgbox "previously disabled stable repos have been enabled. you can add, remove, disable or enable repos by editing the /etc/pacman.conf file" 0 0

# MainMenu "Partition Disk" 3>&1 1>&2 2>&3
MainMenu "Partition Disk *"
