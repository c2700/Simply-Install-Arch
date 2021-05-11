#!/bin/bash

# DIALOG_OK=1
# DIALOG_CANCEL=0
# DIALOG_ESC=255
# DIALOG_HELP=2
# DIALOG_HELP_ITEM_HELP=2
# DIALOG_EXTRA=3

# 3>&1 1>&2 2>&3

RecursiveCallCount=0

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

iw_rechonnect(){
	# $1 - $?
	# $2 - $wireless_dev
	# $3 - $SSID
	# $4 - $pass
	if [[ "${1}" -eq 1 ]]
	then
		dialog --yesno "rescan and connect to a wireless device? " 0 0
		while read -s -n1 -p "line: " line
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
		iw_rechonnect $? $wireless_dev $SSID "$(read -p "$SSID password: ")"
	else
		iwctl station $wireless_dev connect $SSID
		iw_rechonnect $? $wireless_dev $SSID
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
		nmcli device wifi connect "$wifi_name" -a
		if [[ $? -eq 1 ]]
		then
			# for (( rechonnect = "n"; rechonnect != "n" ;))
			for (( rechonnect="n"; rechonnect == "y" ;))
			do
				nmcli device wifi list && read -p "Enter SSID to connect to: " wifi_name
				nmcli device wifi connect "$wifi_name" -a
				read -p "rescan and connect to another ssid? [y/n]" rechonnect
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
		MainMenu "Configure Network **"
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
			MainMenu "Configure Network **"
			;;
		"iwd")
			# iwd_mngr
			dialog --msgbox "iwd used" 0 0
			MainMenu "Configure Network **"
			;;
		*)
			MainMenu "Configure Network **"
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
	LocaleFormat=$(echo -e "\n\n${LocaleDialog[*]}\n" | sed 's/" "/"\n"/g')
	# LocaleFormat=$(echo -e "\n\n${LocaleDialog[@]}\n" | sed 's/" "/"\n"/g')
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
		ConfHost "add users **"
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
	# 	MainMenu "Configure Host +"
	# fi
	# HostOpt=()
	HostOpt=("set hostname *" "set your computer name")
	HostOpt+=("set Locale *" "set your computer language")
	HostOpt+=("set timezone" "configure which timezone you are in")
	HostOpt+=("add users **" "add users")
	HostOpt+=("root password *" "set root password")
	HostOpt+=("Install UI" "Install Desktop Environment or Window Manager")
	HostOpt+=("Set Bash Prompt" "File that's used to tell how the terminal prompt should look like")
	$1="${HostOpt[0]}"
	opt=$(dialog --cancel-label "BACK" --default-item "${1}" --menu "Host Configuration Menu" 0 0 0 "${HostOpt[@]}" 3>&1 1>&2 2>&3)
	if [[ $? -eq 1 ]]
	then
		MainMenu "Configure Host +"
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
		"add users **")
			add_users
			ConfHost "add users **"
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



ConfirmMounts(){
	# texts=("$@")
	Temptexts=$1[@]
	texts=("${!Temptexts}")
	unset Temptexts
	# echo -e "${texts[@]}"
	# read -p "nice: " -n1 

	# 0 - ok
	# 1 - back
	dialog --yes-label "OK" --no-label "Back" --title "partition mount confirmation" --yesno "\nPartition-----Size-----------Filesystem----------Format----MountPoint\n${texts[*]}" 20 75
	CONFIRM_MOUNTS_EXIT_CODE=$?
	if [[ $CONFIRM_MOUNTS_EXIT_CODE -eq 0 ]]
	then
		# MountPartitions "" "" ""
		echo -e "MountPartitions \"\" \"\" \"\""
	elif [[ $CONFIRM_MOUNTS_EXIT_CODE -eq 1 ]]
	then
		PartitionDisk
	fi
}



MountPartitions(){

	# $1 - partitions to mount
	# $2 - mountpt.s
	# $3 - 

	SelectedPartitionsMounted=$1[@]
	SelectedPartitionsMounted=("${!SelectedPartitionsMounted}")
	MntPts=$2[@]
	MntPts=("${!MntPts}")
	MntBlkDev=$3[@]
	MntBlkDev=("${!MntBlkDev}")

	# clear
	# echo "${SelectedPartitionsMounted[@]}"
	# exit

	ConfirmMounts SelectedPartitionsMounted

	MOUNTS_EXIT_CODE=$?
	if [[ $MOUNTS_EXIT_CODE -eq 1 ]]
	then
		PartitionDisk
	elif [[ $MOUNTS_EXIT_CODE -eq 0 ]]
	then
		clear
		rootfs=""
		root_blkdev=""
		echo "1 exp - ${MntPts[@]}"
		echo "2 exp - ${MntBlkDev[@]}"
		echo ""
		read -p "nice" -n1
		for (( i = 0; i < ${#MntBlkDev[@]}; i++ ))
		do
			if [[ "${MntPts[$i]}" =~ "/mnt/"$ ]]
			then
				rootfs="${MntPts[$i]}"
				root_blkdev=${MntBlkDev[$i]}
				echo "0 - root"
				echo "mkfs.ext4  ${MntBlkDev[$i]}"
				echo -e "mounted ${MntBlkDev[$i]} at ${MntPts[$i]}\n\n"

				mount /dev/sdb4 /mnt &>/dev/null
				# mount $rootfs $root_blkdev 
			fi
		done

		for (( i = 0; i < ${#MntPts[@]}; i++ ))
		do
			if [[ "${MntPts[$i]}" == "swap" ]]
			then
				echo "1 - swap"

				echo "using ${MntBlkDev[$i]} as swap and enabled swap"
				# mkswap "${MntBlkDev[$i]}"
				# swapon "${MntBlkDev[$i]}"


			elif [[ "${MntPts[$i]}" =~ "/mnt/"$ ]]
			then
				# mount "/dev/${MntBlkDev[$i]}" "${MntPts[$i]}"
				rootfs="${MntPts[$i]}"
				root_blkdev=${MntBlkDev[$i]}

				if mountpoint /mnt &>/dev/null
				then
					echo ""
				else
					echo "2 - root"

					echo -e "mounted ${MntBlkDev[$i]} at ${MntPts[$i]}\n\n"
					echo "mkfs.ext4 ${MntBlkDev[$i]}"
					# mkfs.ext4 ${MntBlkDev[$i]}
					# mount "${MntBlkDev[$i]}" "${MntPts[$i]}"

				fi
			elif [[ "${MntPts[$i]}" =~ "/mnt/boot/"$ ]]
			then
				# mount /dev/$root /mnt &>/dev/null
				mount /dev/sdb4 /mnt &>/dev/null
				ROOT_MOUNT_EXIT_CODE=$?
				if [[ $ROOT_MOUNT_EXIT_CODE -eq 32 ]] || [[ $ROOT_MOUNT_EXIT_CODE -eq 0 ]]
				then
					echo "3 - boot"

					echo "mkfs.fat -F32 ${MntBlkDev[$i]}"
					# mkfs.fat -F32 ${MntBlkDev[$i]}
					# mount "/dev/${MntBlkDev[$i]}" "${MntPts[$i]}" &>/dev/null
					echo -e "mounted ${MntBlkDev[$i]} at ${MntPts[$i]}\n\n"

				fi
			elif [[ "${MntPts[$i]}" =~ "/mnt/home/"$ ]]
			then
				echo "mkfs.ext4 ${MntBlkDev[$i]}"
				# mount "/dev/$${MntBlkDev[$i]}" "${MntPts[$i]}" &>/dev/null
				echo -e "mounted ${MntBlkDev[$i]} at ${MntPts[$i]}\n\n"
			fi
		done
		echo "done"
		read -p ": " -n1
		MainMenu
	fi
}





DiskListTemp(){
	lsblk -dno name,size,pttype,vendor,model | grep -iv 'loop\|sr[0-9]*' | sed -E 's/\s{8}/ none   /g'
}



# DiskPartInfoTemp(){
# 	if [[ -z $1 ]]
# 	then
# 		lsblk -nlo name,size,fstype,fsver,parttypename /dev/"$1" | grep -i '[a,s]d[a-z][0-9]' | grep -i 'linux filesystem\|ext4\|fat32\|vfat\|efi\|swap' | sed 's/1.0\s{3}//g;s/vfat   FAT32 EFI System/FAT32  EFI System/g;s/swap\s{3}1\s{5}Linux swap/swap   Linux swap/g'
# 	else
# 	    lsblk -nlo name,size,fstype,fsver,parttypename | grep -i '[a,s]d[a-z][0-9]' | grep -i 'linux filesystem\|ext4\|fat32\|vfat\|efi\|swap' | sed -E 's/1.0\s{3}//g;s/vfat\s{3}FAT32 EFI System/FAT32  EFI System/g;s/swap\s{3}1\s{5}Linux swap/swap   Linux swap/g'
# 	fi
# 	echo -e "\n"
# }

DiskPartInfoTemp(){

	if [[ -z $1 ]]
	then
		lsblk -nlo name,size,parttypename,partlabel | grep -ie '[a,s]d[a-z][0-9]|\.\|\linux filesystem\|vfat\|efi\|swap\|linux*home' | sed -E 's/\s{13}/  /g'

	else
	    lsblk /dev/"$1" -nlo name,size,parttypename,partlabel | grep -ie '[a,s]d[a-z][0-9]|\.\|\linux filesystem\|ext4\|fat32\|vfat\|efi\|swap\|linux*home' | sed -E 's/\s{13}/  /g'
	fi
}



EditDisk(){
	disksArgs=$1[@]
	disks=("${!disksArgs}")
	unset DisksArgs

	diskeditors=()

	for i in "gdisk" "cgdisk" "fdisk" "sfdisk" "cfdisk" "parted"
	do
		diskeditors+=("$i" "$i")
	done
	DiskEditor=$(dialog --no-tags --cancel-label "Back" --menu "Disk Editor Menu" 0 0 0 "${diskeditors[@]}" 3>&1 1>&2 2>&3)
	DISKEDITOR_EXIT_CODE=$?
	unset diskeditors
	if [[ $DISKEDITOR_EXIT_CODE -eq 1 ]]
	then
		PartitionDisk
	elif [[ $DISKEDITOR_EXIT_CODE -eq 0 ]]
	then
		for (( i = 0; i < ${#disks[@]}; i++ ))
		do
			clear;reset
			echo -e "Editing Disk '/dev/${disks[$i]}' with $DiskEditor\n\n\n"
			"$DiskEditor" "/dev/${Disks[$i]}"
		done
	fi
}

PartitionDisk(){
	# 3>&1 1>&2 2>&3
	DiskList=($(DiskListTemp | awk '{print $1}'))
	DiskSize=($(DiskListTemp | awk '{print $2}'))
	DiskPartTable=($(DiskListTemp | awk '{print $3}'))
	DiskVendor=($(DiskListTemp | awk '{print $4}'))
	DiskModelTemp=($(DiskListTemp | awk '{ for(i=5;i<=NF;i++){ if (i == 5){ print i" "$i } else if(i > 5){ print $i } } }'))

	DiskListInfo=()
	DiskName=()
	DiskModel=()

	DiskModelString=""
	for i in "${DiskModelTemp[@]}"
	do
		if [[ "$i" =~ ^[5]$ ]] && [[ "$DiskModelString" == "" ]]
		then
			continue
		elif [[ "$i" =~ ^[5]$ ]] && [[ ! -z "$DiskModelString" ]]
		then
			DiskModel+=("$DiskModelString")
			DiskModelString=""
		elif [[ ! ("$i" =~ ^[5]$) ]]
		then
			DiskModelString+="$i"
		fi

		if [[ "$i" == "${DiskModelTemp[-1]}" ]] && [[ ! "$i" =~ ^[5]$ ]] && [[ "$i" =~ ^[a-zA-Z0-9]* ]] && [[ -z "$DiskModelString" ]]
		then
			continue
		elif [[ "$i" == "${DiskModelTemp[-1]}" ]] && [[ ! "$i" =~ ^[5]$ ]] && [[ "$i" =~ ^[a-zA-Z0-9]* ]] && [[ ! -z "$DiskModelString" ]]
		then
			DiskModel+=("$DiskModelString")
		fi

	done

	for (( i = 0; i < ${#DiskModel[@]}; i++ ))
	do
		echo "${DiskModel[$i]}"
	done


	for (( i = 0; i < ${#DiskList[@]}; i++ ))
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

	Disks=($(dialog --scrollbar --cancel-label "Back" --column-separator "|" --title "Disk Selection Menu" --checklist "" 0 0 0 "${DiskListInfo[@]}" 3>&1 1>&2 2>&3))
	if [[ $? -eq 0 ]]
	then
		if [[ -z "${Disks[@]}" ]]
		then
			dialog --msgbox "please select atleast one disk" 0 0
			PartitionDisk
		else
			dialog --extra-button --extra-label "Mount" --ok-label "Back" --cancel-label "Edit" --yesno "Select \"Edit\" for Editting and then mounting the partitions of this disk or select \"Mount\" to only select, format and mount existing Linux filesystem/EFI/swap partitions" 0 0
			PART_MSG_BOX_EXIT_CODE=$?
			# 0 - back
			# 1 - edit
			# 3 - mount
			if [[ $PART_MSG_BOX_EXIT_CODE -eq 0 ]]
			then
				PartitionDisk
			elif [[ $PART_MSG_BOX_EXIT_CODE -eq 1 ]]
			then
				dialog --yes-label "Continue" --no-label "Back" --yesno "Partitions are to be formatted in the diskeditor and the filesystem format is to be created using mkfs (mkfs/mkfs.ext4/mkfs.fat or whatever is used to format the partitions)\n\nPartitions to be created:\n\nMandatory:\n1) EFI partition with a FAT32 filesystem format\n2) Linux Root Partition (shows up as \"Linux filesystem\" in the partition editor) formatted in\n   ext4/ext3/ext2/ext/btrfs/xfs/zfs. Recommended - ext4/btrfs\n\nOptional but recommended:\n1) swap partition with swap filesystem\n\nOptional:\n1) Home partition with same filesystem as Linux Root Partition" 0 0
				CONTINUE_EXIT_CODE=$?
				# exit
				# 0 - continue
				# 1 - back

				if [[ $CONTINUE_EXIT_CODE -eq 0 ]]
				then
					EditDisk Disks
				elif [[ $CONTINUE_EXIT_CODE -eq 1 ]]
				then
					PartitionDisk
				fi
			elif [[ $PART_MSG_BOX_EXIT_CODE -eq 3 ]]
			then
				# MountViewPartitions
				# MountViewPartitions "${Disks[@]}"
				MountViewPartitions Disks
			fi
		fi
	elif [[ $? -eq 1 ]]
	then
		MainMenu
	fi
}


CheckEmptyDisks(){		
	DisksArgs=$1[@]
	Disks=("${!DisksArgs}")
	unset DisksArgs

	NoPartDisksTemp=()
	DisksTemp=()

	NoPartDisks=()
	DiskPartCheck=()

	disk=""
	have=""

	for (( i = 0; i < ${#Disks[@]}; i++ ))
	do
		DiskPartCheck=($(DiskPartInfoTemp "${Disks[$i]}" | grep -vi 'W95 FAT32 (LBA)' | awk '{ print $1 }'))

		if [[ -z ${DiskPartCheck[@]} ]]
		then
			NoPartDisks+=("${Disks[$i]}")
		elif [[ ${#DiskPartCheck[@]} -ge 1 ]]
		then
			continue
		fi
		unset DiskPartCheck
	done

	if [[ ${#NoPartDisks[@]} -gt 1 ]]
	then
		NoPartDisksTemp=("${NoPartDisks[@]}")
		temp="${NoPartDisksTemp[-1]}"
		NoPartDisksTemp[-1]="&"
		NoPartDisksTemp+=("$temp")
		disk="disks"
		have="have"
	elif [[ ${#NoPartDisks[@]} -eq 1 ]]
	then
		NoPartDisksTemp=("${NoPartDisks[@]}")
		disk="disk"
		have="has"
	fi

	dialog --ok-label "Back" --cancel-label "Continue" --extra-button --extra-label "Edit" --yesno "$disk ${NoPartDisksTemp[*]} does not contain any linux installation compatible partitions. Edit the $disk?" 0 0
	EMPTY_DISK_EXIT_CODE=$?
	# 0 - Back
	# 1 - Continue
	# 3 - Edit

	
	if [[ $EMPTY_DISK_EXIT_CODE -eq 0 ]]
	then
		PartitionDisk
	elif [[ $EMPTY_DISK_EXIT_CODE -eq 1 ]]
	then
		if [[ ${#NoPartDisksTemp[@]} -ge 1 ]]
		then
			dialog --msgbox "$disk ${NoPartDisksTemp[*]} $have been discarded and will not be used to install any linux components" 0 0
			unset NoPartDisksTemp

			DisksTemp=("${Disks[@]}")
			for (( i = 0; i < ${#DisksTemp[@]}; i++ ))
			do
				for (( j = 0; j < ${#NoPartDisks[@]}; j++ ))
				do
					if [[ "${Disks[$i]}" == "${NoPartDisks[$j]}" ]]
					then
						unset Disks[$i]
					fi
				done
			done
			unset DisksTemp
		fi
	elif [[ $EMPTY_DISK_EXIT_CODE -eq 3 ]]
	then
		unset NoPartDisksTemp

		dialog --extra-button --extra-label "Edit incompatible Disks" --ok-label "Back" --cancel-label "Edit All Disks" --yesno "Edit disks that are incompatible for linux installation, edit all the disks or go back to the Disk Selection Menu?" 0 0
		EDIT_DISK_EXIT_CODE=$?
		if [[ $EDIT_DISK_EXIT_CODE -eq 3 ]]
		then
			EditDisk NoPartDisks
		elif [[ $EDIT_DISK_EXIT_CODE -eq 1 ]]
		then
			EditDisk Disks
		elif [[ $EDIT_DISK_EXIT_CODE -eq 0 ]]
		then
			PartitionDisk
		fi
	fi
}













MountViewPartitions(){

	# $1 - Disks

	DisksArgs=$1[@]
	Disks=("${!DisksArgs}")
	unset DisksArgs

	DiskPartNameTemp=()
	DiskPartSizeTemp=()
	SelectedPartitionsTemp=()
	DiskPartLabelTemp=()
	DiskPartFsTypeTemp=()
	DiskPartListInfo=()
	DiskPartName=()
	DiskPartFsFormat=()
	DiskPartFsType=()
	DiskPartTypeLabel=()
	DiskPartLabel=()
	SelectedPartitionsMountedText=("")
	MountPoints=()
	MountBlockDev=()
	partitions=()

	NoPartDisks=()

	fat32_efi_parts=()
	linux_fs_ext4_parts=()
	home_parts=()
	swap_parts=()

	fat32_efi_part_count=0
	linux_fs_ext4_part_count=0
	home_part_count=0
	swap_part_count=0

	CheckEmptyDisks Disks

	Disks=($(IFS="";sort <<<${Disks[@]}))

	# for a in "${Disks[@]}"
	for (( a = 0; a < ${#Disks[@]}; a++))
	do
		# echo "$a - ${Disks[$a]}"
		# echo "$a"
		# continue
		# DiskPartName=($(DiskPartInfoTemp "$a" | awk '{ print $1 }'))
		# DiskPartSizeTemp=($(DiskPartInfoTemp "$a" | awk '{ print $2 }'))
		# DiskPartFsTypeTemp=($(DiskPartInfoTemp "$a" | awk '{ print $3" "$4" 1" }'))
		# DiskPartLabelTemp=($(DiskPartInfoTemp "$a" | awk '{ for(i=5;i<=NF;i++){ if (i == 5){ print i" "$i } else if(i > 5){ print $i } } }'))

	    # DiskPartNameTemp=($(DiskPartInfoTemp "${Disks[$a]}" | awk '{ print $1 }'))
	    DiskPartName=($(DiskPartInfoTemp "${Disks[$a]}" | awk '{ print $1 }'))
	    DiskPartSizeTemp=($(DiskPartInfoTemp "${Disks[$a]}" | awk '{ print $2 }'))
	    DiskPartFsTypeTemp=($(DiskPartInfoTemp "${Disks[$a]}" | awk '{ print $3" "$4" 1" }'))
		DiskPartLabelTemp=($(DiskPartInfoTemp "${Disks[$a]}" | awk '{ for(i=5;i<=NF;i++){ if (i == 5){ print i" "$i } else if(i > 5){ print $i } } }'))
		if [[ -z ${DiskPartSizeTemp[*]} ]] && [[ -z ${DiskPartFsTypeTemp[*]} ]] && [[ -z ${DiskPartLabelTemp[*]} ]] && [[ -z ${DiskPartName[*]} ]]
	    then
	        continue
	    else
	    	DiskPartFsTypeString=""
	    	for aa in "${DiskPartFsTypeTemp[@]}"
	    	do
	    		if [[ "$aa" =~ [1] ]]
	    		then
    				DiskPartFsType+=("$(echo "$DiskPartFsTypeString" | sed 's/\s$//g')")
    				# DiskPartFsType+=("$DiskPartFsTypeString | sed 's/\s$//g'")
    				# DiskPartFsType+=("$DiskPartFsTypeString")
	    			DiskPartFsTypeString=""
    			elif [[ "aa" =~ [a-zA-Z] ]]
				then
	    			DiskPartFsTypeString+="$aa "
	    		fi
	    	done
	    	unset DiskPartFsTypeString
	    	# DiskPartFsType=(${DiskPartFsType[@]/\s$/})
	    	# echo ${DiskPartFsType[@]}

	        # for (( b=0; b < ${#DiskPartNameTemp[@]}; b++ ))
	        for (( b=0; b < ${#DiskPartName[@]}; b++ ))
	        do
				LabelStrings=""
				for (( c = 0; c < ${#DiskPartLabelTemp[@]}; c++ ))
				do
					if [[ "${DiskPartLabelTemp[$c]}" =~ [a-zA-Z] ]]
					then
						LabelStrings+="${DiskPartLabelTemp[$c]} "
					elif [[ "${DiskPartLabelTemp[$c]}" =~ [5] ]]
					then
						if [[ "$LabelStrings" != "" ]]
						then
							# DiskPartLabel+=("$LabelStrings")
							DiskPartLabel+=("$(echo "$LabelStrings" | sed 's/\s$//g')")
							LabelStrings=""
						elif [[ "$LabelStrings" == "" ]]
						then
							continue
						fi
					fi
					if [[ "${DiskPartLabelTemp[$c]}" == "${DiskPartLabelTemp[-1]}" ]]
					then
						# DiskPartLabel+=("$LabelStrings")
						DiskPartLabel+=("$(echo "$LabelStrings" | sed 's/\s$//g')")
						LabelStrings=""
					fi
				done

				unset LabelStrings
            	DiskPartInfo="${DiskPartSizeTemp[$b]} | ${DiskPartFsType[$b]} | ${DiskPartLabel[$b]}"
				DiskPartListInfo+=("${DiskPartName[$b]}" "$DiskPartInfo" 0)
				# DiskPartListInfo+=("${DiskPartNameTemp[$b]}" "$DiskPartInfo" 0)
				# DiskPartLabel=()
	        done


			# continue
			partition=($(dialog --cancel-label "Back" --column-separator "|" --title "Partition mount menu" --extra-button --extra-label "Mount" --checklist "Partitions in /dev/${Disks[$a]}" 0 0 0 "${DiskPartListInfo[@]}" 3>&1 1>&2 2>&3))
			PARTITION_EXIT_CODE=$?
			# 0 - ok
			# 1 - back
			# 3 - mount


			: '
			if [[ ${#partition[*]} -eq 0 ]] && ( [[ $PARTITION_EXIT_CODE -eq 0 ]] || [[ $PARTITION_EXIT_CODE -eq 3 ]] )
			if [[ ${#linux_fs_ext4_parts[@]} -eq 0 ]]  && [[ ${#fat32_efi_parts[@]} -eq 0 ]]
			if ([[ ${#linux_fs_ext4_parts[@]} -eq 0 ]]  && [[ ${#fat32_efi_parts[@]} -eq 0 ]] && [[ ${#partition[*]} -eq 0 ]] ) || ( [[ ${#swap_parts[@]} -eq 0 ]] && [[ ${#partition[*]} -eq 0 ]] )
			then
				dialog --msgbox "please select atleast one partition out of EFI/EXT4/swap for system use" 0 0
				# MountViewPartitions
				# MountViewPartitions "${Disks[@]}"
				MountViewPartitions Disks
			elif [[ $PARTITION_EXIT_CODE -eq 0 ]]
			'

			if [[ $PARTITION_EXIT_CODE -eq 0 ]]
			then
				SelectedPartitionsTemp+=("${partition[@]}")
				# SelectedPartitionsTemp+=()
				for (( c = 0; c < ${#SelectedPartitionsTemp[@]}; c++ ))
				do
					# a=c
					# ((a+=1))
					# for (( d = 0; d < ${#DiskPartNameTemp[@]}; d++ ))
					for (( d = 0; d < ${#DiskPartName[@]}; d++ ))
					do
						# if [[ "${SelectedPartitionsTemp[$c]}" == "${DiskPartNameTemp[$d]}" ]]
						if [[ "${SelectedPartitionsTemp[$c]}" == "${DiskPartName[$d]}" ]]
						then
							if [[ "${DiskPartFsType[$d]}" == "Linux filesystem" ]]
							then
								linux_fs_ext4_parts+=("${DiskPartFsType[$c]}")
								((linux_fs_ext4_part_count+=1))
							elif [[ "${DiskPartFsType[$d]}" == "Linux swap" ]]
							then
								swap_parts+=("${DiskPartFsType[$c]}")
								((swap_part_count+=1))
							elif [[ "${DiskPartFsType[$d]}" == "EFI System" ]]
							then
								fat32_efi_parts+=("${DiskPartFsType[$c]}")
								((fat32_efi_part_count+=1))
							fi
						fi
					done
				done
				DiskPartListInfo=()
				DiskPartFsType=()

			

				# echo "linux_fs_ext4_parts - ${linux_fs_ext4_parts[@]}"
				# echo "swap_parts - ${swap_parts[@]}"
				# echo "fat32_efi_parts - ${fat32_efi_parts[@]}"
			elif [[ $PARTITION_EXIT_CODE -eq 1 ]]
			then
				# DiskPartListInfo=()
				PartitionDisk
			elif [[ $PARTITION_EXIT_CODE -eq 3 ]]
			then
				SelectedPartitionsTemp+=("${partition[@]}")
				# SelectedPartitionsTemp+=()
			fi
		fi
		DiskPartListInfo=()
		DiskPartSizeTemp=()
		DiskPartFsType=()
		DiskPartLabel=()
		# read -p "nce: " -n1
		# continue
	done
	# exit

	echo 

	# total_parts=${#fat32_efi_parts[@]}+${#linux_fs_ext4_parts[@]}+${#swap_parts[@]}+${#home_parts[@]}
	total_parts=$(($fat32_efi_part_count+$linux_fs_ext4_part_count+$swap_part_count+$home_part_count))


	if [[ $swap_part_count -eq 0 ]] && [[ $home_part_count -eq 0 ]] && [[ $fat32_efi_part_count -gt 1 ]] && [[ $linux_fs_ext4_part_count -gt 1 ]] && [[ $swap_part_count -eq 1 ]]
	then
		dialog --yesno "no home or swap partitions detected. Continue without them?" 0 0
		PART_EXIT_CODE=$?
		if [[ $PART_EXIT_CODE -eq 0 ]]
		then
			ConfirmMounts SelectedPartitionsMountedText
			MOUNTS_EXIT_CODE=$?
			if [[ $MOUNTS_EXIT_CODE -eq 1 ]]
			then
				PartitionDisk
			elif [[ $MOUNTS_EXIT_CODE -eq 0 ]]
			then
				# MountPartitions "${SelectedPartitionsMountedText[@]}" "${MountPoints[@]}" "${MountBlockDev[@]}"
				MountPartitions SelectedPartitionsMountedText MountPoints MountBlockDev
				# echo "MountPartitions SelectedPartitionsMountedText MountPoints MountBlockDev"
			fi
		elif [[ $PART_EXIT_CODE -eq 1 ]]
		then
			# MountViewPartitions "${Disks[@]}"
			# PartitionDisk
			# # MountViewPartitions
			MountViewPartitions Disks

		fi
		# DiskPartListInfo=()


	# elif ( [[ ${#fat32_efi_parts[@]} -gt 1 ]] && [[ ${#linux_fs_ext4_parts[@]} -gt 1 ]] ) || [[ $total_parts -gt 4 ]]
	elif [[ $fat32_efi_part_count -gt 1 ]] && [[ $linux_fs_ext4_part_count -gt 1 ]]
	then
		dialog --msgbox "multiple essential linux partitions detected (boot and ext4). please select one partition for each filesystem" 0 0
		# PartitionDisk
		# MountViewPartitions "${Disks[@]}"
		MountViewPartitions Disks

	elif [[ $fat32_efi_part_count -gt 1 ]]
	then
		dialog --msgbox "multiple boot partitions detected. please select one" 0 0
		# PartitionDisk
		# MountViewPartitions "${Disks[@]}"
		MountViewPartitions Disks

	elif [[ $linux_fs_ext4_part_count -gt 1 ]]
	then
		dialog --msgbox "multiple linux filesystems detected. please select one" 0 0
		# PartitionDisk
		# MountViewPartitions "${Disks[@]}"
		MountViewPartitions Disks

	elif [[ -z ${DiskPartName[@]} ]]
	then
		dialog --yes-label "Edit Disk" --no-label "Select Disk" --yesno "Disk does not contain any partitions. Edit The Disk?" 0 0
		EMPTY_DISK_EXIT_CODE=$?
		if [[ $EMPTY_DISK_EXIT_CODE -eq 0 ]]
		then
			dialog --yes-label "Continue" --no-label "Back" --yesno "Partitions are to be formatted in the diskeditor and the filesystem format is to be created using mkfs (mkfs/mkfs.ext4/mkfs.fat or whatever is used to format the partitions)\n\nPartitions to be created:\n\nMandatory:\n1) EFI partition with a FAT32 filesystem format\n2) Linux Root Partition (shows up as \"Linux filesystem\" in the partition editor) formatted in\n   ext4/ext3/ext2/ext/btrfs/xfs/zfs. Recommended - ext4/btrfs\n\nOptional but recommended:\n1) swap partition with swap filesystem\n\nOptional:\n1) Home partition with same filesystem as Linux Root Partition" 0 0
				CONTINUE_EXIT_CODE=$?
				# echo $CONTINUE_EXIT_CODE
				# exit
				# 0 - continue
				# 1 - back
				if [[ $CONTINUE_EXIT_CODE -eq 0 ]]
				then
					EditDisk "${Disks[@]}"
				elif [[ $CONTINUE_EXIT_CODE -eq 1 ]]
				then
					PartitionDisk
				fi
			elif [[ $EMPTY_DISK_EXIT_CODE -eq 1 ]]
			then
				PartitionDisk
			fi


	elif [[ $total_parts -eq 0 ]]
	then
		dialog --msgbox "no partitions selected. please select an EFI and a linux filesystem partition (mandatory). Select a few optional partitions as well (if needed or wanted but not necessary)" 0 0
	# PartitionDisk
	# # MountViewPartitions
	# MountViewPartitions "${Disks[@]}"
	MountViewPartitions Disks



	elif [[ $fat32_efi_part_count -eq 0 ]]
	then
		dialog --msgbox "no boot partition detected" 0 0
		# DiskPartListInfo=()
		PartitionDisk


	elif [[ $linux_fs_ext4_part_count -eq 0 ]]
	then
		dialog --msgbox "no linux root system partition detected" 0 0
		# DiskPartListInfo=()
		PartitionDisk


	elif [[ $swap_part_count -eq 0 ]]
	then
		dialog --yesno "no swap partition detected. Recommended to have one. continue without a swap partition?" 0 0
		SWAP_DIALOG_EXIT_CODE=$?
		# echo $SWAP_DIALOG_EXIT_CODE
		if [[ $SWAP_DIALOG_EXIT_CODE -eq 1 ]]
		then
			PartitionDisk
			# # MountViewPartitions
			# MountViewPartitions "${Disks[@]}"
			MountViewPartitions Disks
		elif [[ $SWAP_DIALOG_EXIT_CODE -eq 0 ]]
		then
			ConfirmMounts SelectedPartitionsMountedText
			MountPartitions SelectedPartitionsMountedText MountPoints MountBlockDev
		fi
		# DiskPartListInfo=()

	elif [[ $home_part_count -eq 0 ]]
	then
		dialog --yesno "no home partition detected. continue without home partition?" 0 0
		HOME_PART_EXIT_CODE=$?
		if [[ $HOME_PART_EXIT_CODE -eq 0 ]]
		then
			# ConfirmMounts SelectedPartitionsTemp
			ConfirmMounts SelectedPartitionsMountedText
		elif [[ $HOME_PART_EXIT_CODE -eq 1 ]]
		then
			PartitionDisk
		fi

	elif [[ $linux_fs_ext4_part_count -eq 0 ]] && [[ $fat32_efi_part_count -eq 0 ]]
	then
		dialog --msgbox "no boot and system partitions detected. system cannot be installed." 0 0
		# # MountViewPartitions
		# MountViewPartitions "${Disks[@]}"
		# MountViewPartitions Disks
		# DiskPartListInfo=()
		PartitionDisk

	elif [[ $home_part_count -eq 0 ]] && [[ $swap_part_count -eq 0 ]]
	then
		# 1 - no
		# 0 - yes
		dialog --msgbox "no boot and system partitions detected. system cannot be installed. Please Select Disks for linux installation from the Disk Menu" 0 0
		PartitionDisk
	fi
}








InstallArch(){

	if ! mountpoint /mnt &>/dev/null
	then
		dialog --msgbox "root partition not mounted" 0 0
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

		EDITORS_EXIT_CODE=$?
		if [[ $EDITORS_EXIT_CODE -eq 0 ]]
		then
			# editors="${editors[@]}"
			if [[ $editors == "" ]]
			then
				packages="${packages}"
			else
				packages="${packages} ${editors[@]}"
			fi
		fi

		if [[ $EDITORS_EXIT_CODE -eq 3 ]]
		then
			packages="${packages}"
			# break
		fi

		if [[ $EDITORS_EXIT_CODE -eq 1 ]]
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
		echo ""
		ARCH_INSTALL_EXIT_CODE=$?
		if [[ $ARCH_INSTALL_EXIT_CODE -eq 0 ]]
		then
			dialog --msgbox "Created fstab entry. you can generate the fstab of your disk by \"executing genfstab -U {arch-chroot directory} > {arch-chroot directory}/etc/fstab\" (i.e. if anythin went wrong with the fstab entry)" 0 0
			bootloaderid="$(dialog --inputbox "Bootloader ID - Input Any Text" 0 0)"
			# grub-install -v --boot-directory="/mnt/boot" --bootloader-id "$bootloaderid" --efi-directory="/mnt/boot" --recheck --removable --target x86_efi-efi
			echo "grub-install -v --boot-directory=\"/mnt/boot\" --bootloader-id \"$bootloaderid\" --efi-directory=\"/mnt/boot\" --recheck --removable --target x86_efi-efi"
			if [[ $? -eq 0 ]]
			then
				MainMenu "Install Arch *"
			else
				dialog --msgbox "could not install grub-bootloader. you execute \'grub-install --help | less\' on one tty and run \'grub-install <options>\' on another tty. \n\nDO NOT USE THE \'--force\' option.You can open tty's by pressing ctrl+alt+<F1>-<F6> with each function key corresponding to their tty id\n\n Go back to the Main Menu or exit to the tty?"
			fi
		elif [[ $ARCH_INSTALL_EXIT_CODE -eq 1 ]]
		then
			dialog --msgbox "could not install Arch." 0 0
		fi
	fi
}














Repo_Enable(){
	dialog --backtitle "Written by c2700" --yesno "enable \"multilib\" repo for packages with support for multiple architectures?" 5 80
	REPO_ENABLE_EXIT_CODE=$?
	if [[ REPO_ENABLE_EXIT_CODE -eq 1 ]]
	then
		dialog --backtitle "Written by c2700" --no-label "exit" --yes-label "continue installation" --yesno "multilib repo not enabled. To enable it restart the script or uncomment lines 94 and 95 in file \"/etc/pacman.conf\"" 6 63
		RESTART_EXIT_CODE=$?
		if [[ $RESTART_EXIT_CODE -eq 1 ]]
		then
			  exit
		elif [[ $RESTART_EXIT_CODE -eq 0 ]]
		then
			echo ""
		fi
	elif [[ REPO_ENABLE_EXIT_CODE -eq 0 ]]
	then
		# sed '94s/\#\[/"["' /etc/pacman.conf
		# sed '95s/\#\[/""' /etc/pacman.conf
		dialog --backtitle "Written by c2700" --msgbox "\"multilib\" repo has been enabled. you can add, remove, disable or enable repos by editing the \"/etc/pacman.conf\" file" 0 0
	fi
}





MainMenu(){

	# $1 - menu option item

	clear
    # check if dialog is installed
	ls /usr/bin/dialog &>/dev/null

	if [[ $? -eq 1 ]]
	then
		echo -e "dialog not installed.\n"
		read -s -n1 -p "press any key to install the git provided dialog package "
		pacman -Uvd --noconfirm "$(ls dialog*)"
		if [[ $? -eq 1 ]]
		then
			echo -e "\n\ndialog could not be installed.\n\nPlease install provided dialog packages by typing \"pacman -Uvd <package name>\" with or without the \"--noconfirm\" argument.\n\ncurrent directory:\n$(pwd)\n\npackages in this directory:\n$(ls *.pkg*).\n\n\nexiting...\n\n"
			exit
		else
			dialog --msgbox "installed dialog" 0 0
		fi
	fi

	menuopt=("Partition Disk **" "format/Partition/select Hard Disks and mount partitions")
	menuopt+=("Configure Network **" "Connect to Network")
	menuopt+=("Install Arch *" "Install the base system")
	menuopt+=("Configure Host +" "Personalize the machine by setting Hostname, adding users etc.")
	menuopt+=("Reboot" "Reboot the computer")

	menuitem=$(dialog --default-item "${1}" --backtitle "Written by c2700" --cancel-label "Exit" --title "Install Menu" --menu "To install arch all options followed by\n  i) '**' are priority 1\n ii) '*'are priority 2\niii) '+'are priority 3\n\nThe rest are optional" 0 0 0 "${menuopt[@]}" 3>&1 1>&2 2>&3)


	if [[ $? -eq 1 ]]
	then
		clear;reset;exit
	fi

	case $menuitem in
		"Partition Disk **")
			PartitionDisk
			# MainMenu "Partition Disk **"
			;;
		"Configure Network **")
			# dialog --msgbox "Configure Network" 0 0
			ConfNet
			if [[ $? -eq 1 ]]
			then
				MainMenu "Configure Network **"
			fi
			;;

		"Install Arch *")
				InstallArch
			;;


		"Configure Host +")
			: '
			arch-chroot /mnt
			mountpoint /mnt
			if [[ $? -eq 1 ]]
			then
				# dialog --msgbox "could not chroot int /mnt" 0 0
				dialog --msgbox "no root partition set" 0 0
			else
			'
				ConfHost "set hostname *"
			# fi
			MainMenu "Configure Host +"
			;;

		"Reboot")
			dialog --extra-button --extra-label "cancel" --msgbox "Reboot the machine" 0 0
			if [[ $? -eq 3 ]]
			then
				MainMenu "Reboot"
			else
				dialog --yesno "save basic customization instructions in the arch partition? It will be stored in the /home/customize.txt file of your arch install location. use less, more, cat or a text editor like vim, vi, emacs or nano to view the file" 0 0
				if [[ $? -eq 1 ]]
				then
					dialog --msgbox "saved basic customization instructions" 0 0
					# echo -e "change hostname - vim /etc/hostname\ncreate users - useradd -m\n<username> -G power,storage,wheel -g users\nset or change user password - passwd <username>\nset or change user password - passwd\nset locale - vim /etc/locale.gen, comment '#' to ignore and uncomment to generate or use the locale\n\n(DE - Desktop Environment, WM - Window Manager) to install a DE - install a minimal DE package or the group using the '-g' argument in pacman and a lockscreen manager. enable the lockscreen manager using the systemctl tool and write the DE session name in the /home/<user name>/.xinitrc file\n to install a WM - install a WM and the lockscreen manager will pick it up (if enabled)\nset timezone - soft link (ln -sf) /usr/share/zoneinfo/<continent>/<region> /etc/localtime execute hwclock -w -v (-v is optional if you prefer verbosity (basically more details of what's going on ))" > /mnt/home/customize.txt
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

# Repo_Enable
MainMenu "Partition Disk **" 3>&1 1>&2 2>&3
