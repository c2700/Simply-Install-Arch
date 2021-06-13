#!/bin/bash

###############################################################################################
#                                                                                             #
# Before you read the script or make any changes to the script and judge me for my scripting  #
# behaviours and/or style (in case you wana know how this script file works), just wana let   #
# you know a few things in case you are trying to read this script file.			  		  #
#																							  #
# 1) you will see a lot of 'a to z' (mostly a,b,i,j,k,g and h) var.s used as iterators cuz    #
# 	 I could'nt keep track of what iterator was used in what loop. And also As I have		  #
# 	 mentioned in the "README.md", this is something that I came with on the spot and only    #
# 	 had a really vague picture of how this script should behave/work.						  #
# 2) Never came up with a script workflow and never could come up with one cuz of how vague   #
# 	 the behaviour/workflow I had in mind was and don't have a workflow even now. Just 		  #
# 	 typing away. 																		 	  #
# 3) workarounds and beahviours that I felt that needed to be added came to mind as and when  #
# 	 I was writing and running this script.											  		  #
# 4) With all of the above mentioned you might find this codebase to be all over the place.   #
# 5) You will find a lot of "unset". I did it to use the same variable name in the local      #
#    scope of other functions                                                                 #
#                                                                                             #
#                                                                                             #
#                                                                                             #
# Also, I'm open to any constructive criticism (IF you find the codebase to be shitty i.e. ) #
###############################################################################################

# DIALOG_OK=1
# DIALOG_CANCEL=0
# DIALOG_ESC=255
# DIALOG_HELP=2
# DIALOG_HELP_ITEM_HELP=2
# DIALOG_EXTRA=3

# 3>&1 1>&2 2>&3
# rqeuired global var
# RecursiveCallCount=0 # wish I knew a pvt. variable way of keeping track of Recursive func calls

# commonly used code blocks
GuageMeter(){
	# $1 - guagebox text
	# $2 - number
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


DiscardFromArray(){
	# $1 - Array to unset from
	# $2 - Reference Array

	UnsetArray=$1[@]
	UnsetArray=(${!UnsetArray})

	RefArray=$2[@]
	RefArray=(${!RefArray})

	for i in "${RefArray[@]}"
	do
		UnsetArraySize=${#UnsetArray[@]}
		for (( j = 0; j < $UnsetArraySize; j++ ))
		do
			if [[ "$i" == "${UnsetArray[$j]}" ]]
			then
				unset UnsetArray[$j]
				UnsetArray=($(IFS="";sort <<<${UnsetArray[@]}))
			elif [[ "$i" != "${UnsetArray[$j]}" ]]
			then
				continue
			fi
		done
	done
	echo "${UnsetArray[@]}"
}


TempArrayWithAmpersandHasHaveTexts(){
	# $1 - Size of Temp Array
	local TempArraySize=$1

	if [[ $TempArraySize -eq 1 ]]
	then
		disk="disk"
		have="has"
	elif [[ $TempArraySize -gt 1 ]]
	then
		disk="disks"
		have="have"
	fi
	echo "$disk $have"
}


TempArrayWithAmpersand(){

	# $1 - TempArray

	local TempArrayArgs=$1[@]
	local TempArray=(${!TempArrayArgs})
	unset TempArrayArgs

	if [[ ${#TempArray[@]} -eq 1 ]]
	then
		:
	elif [[ ${#TempArray[@]} -gt 1 ]]
	then
		temp="${TempArray[-1]}"
		TempArray[-1]="&"
		TempArray+=("$temp")
	fi
	echo "${TempArray[@]}"
}


IsArrayEmpty(){
	local TempArrayArgs=$1[@]
	local TempArray=("${!TempArrayArgs}")
	unset TempArrayArgs
	if [[ -z "${TempArray[@]}" ]]
	then
		return 1
	elif [[ -n "${TempArray[@]}" ]]
	then
		return 0
	fi
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
	NMList=()
	ping -c4 google.com &>/dev/null | GuageMeter "Checking for network availablity" 1
	if [[ ${PIPESTATUS[0]} -eq 0 ]]
	then
		dialog --title "Installed Network Manager" --msgbox "network available" 0 0
		MainMenu "Configure Network **"
	else
		dialog --title "Network Status" --msgbox "network not available. will search for availble network managers" 0 0
	fi


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

	pkgs=""
	wmopts=()
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
	# pacstrap /mnt $pkgs
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
			: '
			elif [[ ${PIPESTATUS[0]} -eq 0 ]]
			then
				dialog --msgbox "timezone could not be set ${zone}" 0 0
			fi
			'
		fi
	fi
}




SetLocale(){

	# user set locale

	LOCALE=()
	# cat "/mnt/etc/locale.gen" | grep -i '#\w' | sed 's/#//' > locales.txt
	cat "/etc/locale.gen" | grep -i '#\w' | sed 's/#//' > locales.txt
	# cat "/mnt/etc/locale.gen" | grep -i '#\w' | sed 's/#//' > locales.txt

	dialog --msgbox "when you press a character and you don't see the character, just keep that charcter held until you see the cursor" 0 0

	while read txt
	do
		LOCALE+=("$txt")
		LOCALE+=("$txt")
		LOCALE+=(OFF)
	done < locales.txt

	rm -rf locales.txt
	# back - 1
	# ok - 0
	LocaleDialog=$(dialog --scrollbar --visit-items --cancel-label "BACK" --title "Locale Selection Menu" --buildlist "\nUse the space bar to move locale options between the panes and use the tab for moving in between spacess. If no locale is selected then the deafult UTF-8 and ISO-8859 versions of the US english locales will be set \n\n       disabled locales enabled locales" 0 0 0 "${LOCALE[@]}" 3>&1 1>&2 2>&3)

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
		case $? in
			0) hostname="arch" ;;
			1) SetHostName ;;
		esac
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

	MountTextsTemp=$1[@]
	MountTexts=("${!MountTextsTemp}")
	unset MountTextsTemp
	echo -e "${MountTexts[@]}"
	read -p "nice: " -n1

	# 0 - ok
	# 1 - back
	dialog --yes-label "OK" --no-label "Back" --title "partition mount confirmation" --yesno "\nPartition-----Size-----------Filesystem----------Format----MountPoint\n${MountTexts[*]}" 20 75
	return =$?
}



DiskListTemp(){
	Disk=$1
	if [[ -n "$Disk" ]]
	then
		lsblk "/dev/$Disk" -dno name,size,pttype,vendor,model | grep -iv 'loop\|sr[0-9]*' | sed -E 's/\s{8}/ none   /g'
	elif [[ -z $1 ]]
	then
		lsblk -dno name,size,pttype,vendor,model | grep -iv 'loop\|sr[0-9]*' | sed -E 's/\s{8}/ none   /g'
	fi
}




DiskPartInfoTemp(){

	if [[ -z $1 ]]
	then
		lsblk -nlo name,size,parttypename,partlabel | grep -ie '[a,s]d[a-z][0-9]|\.\|\linux filesystem\|vfat\|efi\|swap\|linux*home' | sed -E 's/\s{13}/  /g'

	else
	    lsblk /dev/"$1" -nlo name,size,parttypename,partlabel | grep -ie '[a,s]d[a-z][0-9]|\.\|\linux filesystem\|ext4\|fat32\|vfat\|efi\|swap\|linux*home' | sed -E 's/\s{13}/  /g'
	fi
}


CheckEditMount(){
	local m_DisksArgs=$1[@]
	local m_Disks=${!m_DisksArgs}
	unset m_DisksArgs

	local PREVIOUS_FUNC_EXIT_CODE=$2
	# case $2 in
	case $PREVIOUS_FUNC_EXIT_CODE in
		1)
			local m_NoPartsDisks=($(DisksWithoutPartitions m_Disks))
			local m_NoPartsDisksTemp=("${m_NoPartsDisks[@]}")
			m_NoPartsDisksTemp=($(TempArrayWithAmpersand m_NoPartsDisksTemp))
			local diskhave=($(TempArrayWithAmpersandHasHaveTexts ${#m_NoPartsDisks[@]}))

			local m_DisksTemp=("${m_Disks[@]}")
			m_DisksTemp=($(TempArrayWithAmpersand m_Disks))
			local diskhave0=($(TempArrayWithAmpersandHasHaveTexts ${#m_Disks[@]}))

			local m_PartTableDisks=(${m_Disks[@]})
			m_PartTableDisks=($(DiscardFromArray m_PartTableDisks m_NoPartsDisks))
			local m_PartTableDisksTemp=($(TempArrayWithAmpersand m_PartTableDisks))
			local diskhave12=($(TempArrayWithAmpersandHasHaveTexts ${#m_PartTableDisks[@]}))

			# echo "1) m_NoPartsDisks -> ${m_NoPartsDisks[@]}"
			# echo "2) m_NoPartsDisksTemp -> ${m_NoPartsDisksTemp[@]}"
			# echo "3) m_Disks -> ${m_Disks[@]}"
			# echo "4) m_DisksTemp -> ${m_DisksTemp[@]}"
			# echo "5) m_PartTableDisks -> ${m_PartTableDisks[@]}"
			# echo "5) m_PartTableDisksTemp -> ${m_PartTableDisksTemp[@]}"
			read -p "did i studr?" -n1
			if [[ "${m_NoPartsDisks[@]}" == "${m_Disks[@]}" ]]
			then
				dialog --yes-label "Back" --no-label "Edit" --yesno "${diskhave[0]} ${m_DisksTemp[*]} have not been edited. Go Back to Editing ${diskhave[0]} ${m_DisksTemp[*]} or go back to the Disk Selection Menu" 0 0
				case $? in
					0) PartitionDisk ;;
					1)
						EditDisk m_Disks
						DisksWithoutPartitionsPresent m_Disks
						local DISKSWITHOUTPARTITIONSPRESENT_EXIT_CODE=$?
						case $? in
							0)
								MountViewPartitions m_Disks
								;;
							1)
								CheckEditMount m_Disks DISKSWITHOUTPARTITIONSPRESENT_EXIT_CODE
								;;
						esac
						;;
				esac

			elif [[ "${m_NoPartsDisks[@]}" != "${m_Disks[@]}" ]]
			then
				dialog --ok-label "Back" --cancel-label "Edit" --extra-button --extra-label "Discard ${diskhave12[0]}" --yesno "${diskhave[0]} ${m_NoPartsDisksTemp[*]} have not been edited. Edit ${diskhave[0]} ${m_NoPartsDisksTemp[*]}, go back to the Disk Selection Menu or Discard ${diskhave[0]} ${m_NoPartsDisksTemp[*]} and use ${diskhave12[0]} ${m_PartTableDisks[*]}?" 0 0
				case $? in
					0) PartitionDisk ;;
					1)
						EditDisk m_Disks
						DisksWithoutPartitionsPresent m_Disks
						local DISKSWITHOUTPARTITIONSPRESENT_EXIT_CODE=$?
						case $? in
							0)
								MountViewPartitions m_Disks
								;;
							1)
								CheckEditMount m_Disks DISKSWITHOUTPARTITIONSPRESENT_EXIT_CODE
								;;
						esac
						;;
					3)
						m_Disks=($(DiscardFromArray m_Disks m_NoPartsDisks))
						dialog --msgbox "Discarded ${diskhave0[0]}. Using ${diskhave[0]} ${m_Disks[@]}" 0 0
						MountViewPartitions m_Disks
						;;
				esac
			fi
			;;
		0) MountViewPartitions m_Disks ;;
	esac
}





IsPartitionTablePresent(){
	local m_disksArgs="$1"
	# local m_disksArgs=$1[@]
	# local m_Disks=("${!m_disksArgs}")
	# unset m_disksArgs

	local m_parttable="$(DiskListTemp "$1" | awk '{ print $3 }')"
	if [[ "$m_parttable" == "none" ]]
	then
		return 1
	elif [[ "$m_parttable" != "none" ]]
	then
		return 0
	fi
}

DisksWithoutPartitionTable(){
	local m_disksArgs=$1[@]
	local m_Disks=("${!m_disksArgs}")
	unset m_disksArgs
	local m_NoPartTableDisks=()

	local m_NoPartTableDisk=""
	local a=0
	for (( i=0; i < ${#m_Disks[@]}; i++ ))
	do
		IsPartitionTablePresent "${m_Disks[$i]}"
		case $? in
			0) continue ;;
			1)
				m_NoPartTableDisk="${m_Disks[$i]}"
				a=$i
				break
				;;
		esac
	done

	if [[ -n "$m_NoPartTableDisk" ]]
	then
		# for (( i = $a; i < ${#m_Disks[@]}; i++ ))
		for i in ${m_Disks[@]:$a}
		do
			m_NoPartTableDisks+=("$i")
			# m_NoPartTableDisks+=("${m_Disks[$i]}")
		done
		echo "${m_NoPartTableDisks[@]}"
	fi
}

DisksWithoutPartitionsPresent(){
	local DisksArgs=$1[@]
	local Disks=("${!DisksArgs}")
	unset DisksArgs

	m_NoPartsDisks=""
	for i in {Disks[@]}
	do
		local m_check=($(DiskPartInfoTemp | awk '{ print $1 }'))
		if [[ -n ${m_check[@]} ]]
		then
			m_NoPartsDisks="$i"
			break
		fi
	done

	if [[ -n "$m_NoPartsDisks" ]]
	then
		unset m_NoPartsDisks
		return 1
	elif [[ -z ${m_NoPartsDisks[@]} ]]
	then
		unset m_NoPartsDisks
		return 0
	fi
}

DisksWithoutPartitions(){
	local DisksArgs=$1[@]
	local Disks=("${!DisksArgs}")
	unset DisksArgs

	local m_NoPartsDisks=()
	for i in ${Disks[@]}
	do
		echo "$i"
		local m_check=($(DiskPartInfoTemp "$i" | awk '{ print $1 }'))
		echo "${m_check[@]}" 3>&1 1>&2 2>&3
		if [[ -n ${m_check[@]} ]]
		then
			m_NoPartsDisks+=("$i")
		fi
		unset m_check
	done
	echo "${m_NoPartsDisks[@]}"
}


EditDisk(){
	local disksArgs=$1[@]
	local m_Disks=("${!disksArgs}")
	unset disksArgs

	# WritePartitionTable m_Disks

	local diskeditors=()

	for i in "gdisk" "cgdisk" "fdisk" "sfdisk" "cfdisk" "parted"
	do
		which "$i" &>/dev/null
		if [[ $? -eq 0 ]]
		then
			diskeditors+=("$i" "$i")
		else
			continue
		fi
	done

	local disksTemp=("${m_Disks[@]}")
	disksTemp=($(TempArrayWithAmpersand disksTemp))
	# local DiskEditor=""
	# DiskEditor="$(dialog --no-tags --cancel-label "Back" --menu "Disk Editor Menu\n\nSelect a Disk Editor to Edit the $disk ${disksTemp[*]}" 0 0 0 "${diskeditors[@]}" 3>&1 1>&2 2>&3)"
	DiskEditor="$(dialog --no-tags --cancel-label "Back" --menu "Disk Editor Menu\n\nSelect a Disk Editor to Edit the $disk ${disksTemp[*]}" 0 0 0 "${diskeditors[@]}" 3>&1 1>&2 2>&3)"
	case $? in
		0)
			local m_NonePartDisks=()
			# dialog --no-label "Back" --yes-label "OK" --yesno "partition type -> partition filesystem\n\nPartitions to be created:\n\nMandatory:\n1) EFI system partition -> FAT32\n2) Linux filesystem -----> ext4 (This is the linux root partition)\n\nOptional but recommended:\n1) Linux swap -> swap (used when machine runs out of RAM/physical memory)\n\nOptional:\n1) Linux user's home -> same filesystem as the Linux Root Partition" 0 0
			dialog --no-label "Back" --yes-label "OK" --yesno "					partition type ----------------> partition filesystem format\n\nPartitions to be created and formatted to:\n	Mandatory:\n		1) EFI system partition -> FAT32(This is where the bootloader and the kernel resides)\n		2) Linux filesystem -----> ext4 (This is the linux root partition)\n\n	Optional but recommended:\n		1) Linux swap -> swap (used when machine runs out of RAM/physical memory)" 0 0
			case $? in
				0)
					# for (( i = 0; i < ${#m_Disks[@]}; i++ ))
					for i in "${m_Disks[@]}"
					do
						clear;reset
						printf "\E[1m\t\t\t\t\tEditing Disk '/dev/$i' with $DiskEditor\n\n\n\E[m"
						# "$DiskEditor" "/dev/${m_Disks[$i]}"
						"$DiskEditor" "/dev/$i"
						local m_DiskPartCheck=()
						# m_DiskPartCheck=($(DiskPartInfoTemp "${m_Disks[$i]}" | awk '{ print $1 }'))
						m_DiskPartCheck=($(DiskPartInfoTemp "$i" | awk '{ print $1 }'))
						if [[ -n "${m_DiskPartCheck[@]}" ]]
						then
							# m_NonePartDisks+=("${m_Disks[$i]}")
							m_NonePartDisks+=("$i")
						elif [[ -z "${m_DiskPartCheck[@]}" ]]
						then
							continue
						fi
						unset m_DiskPartCheck
					done
					;;
				1) PartitionDisk ;;
			esac
			;;
		1) PartitionDisk
			;;
	esac
	unset diskeditors
}



WritePartitionTable(){
	local PartTableTemp=()
	PartTableTemp+=("GPT" "supports 128 primary partitions, mutiple bootloaders, storage more than 2TB")
	PartTableTemp+=("MBR" "supports 4 primary partitions, max storage of 2TB")
	local PartTable=""
	PartTable="$(dialog --cancel-label "Back" --menu "Partition Table Menu\n\nSelect the partition Table to be written on $disk ${m_NoneDisksTemp[*]}" 0 0 0 "${PartTableTemp[@]}" 3>&1 1>&2 2>&3)"
	case $? in
		0)
			local m_DisksArgs=$1[@]
			local m_Disks=("${!m_DisksArgs}")
			unset m_DisksArgs

			local diskhave=($(TempArrayWithAmpersandHasHaveTexts ${#m_Disks[@]}))
			local m_DisksTemp=("${m_Disks[@]}")
			m_DisksTemp=($(TempArrayWithAmpersand m_DisksTemp))
			################################
			# rewrite disk partition table #
			################################
			dialog --msgbox "$PartTable Partiton Table set on ${diskhave[0]} ${m_DisksTemp[*]}" 0 0 3>&1 1>&2 2>&3
			unset diskhave
			;;
		1)
			PartitionDisk
			;;
	esac
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
		elif [[ "$i" =~ ^[5]$ ]] && [[ -n "$DiskModelString" ]]
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
		elif [[ "$i" == "${DiskModelTemp[-1]}" ]] && [[ ! "$i" =~ ^[5]$ ]] && [[ "$i" =~ ^[a-zA-Z0-9]* ]] && [[ -n "$DiskModelString" ]]
		then
			DiskModel+=("$DiskModelString")
		fi
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

	# Disks=($(dialog --scrollbar --cancel-label "Back" --column-separator "|" --title "Disk Selection Menu" --checklist "" 0 0 0 "${DiskListInfo[@]}" 3>&1 1>&2 2>&3))
	Disks=($(dialog --scrollbar --cancel-label "Back" --column-separator "|" --checklist "Disk Selection Menu" 0 0 0 "${DiskListInfo[@]}" 3>&1 1>&2 2>&3))
	case $? in
		1) MainMenu ;;
		0)
			if [[ -z "${Disks[@]}" ]]
			then
				dialog --msgbox "please select atleast one disk" 0 0
				PartitionDisk
			elif [[ -n "${Disks[@]}" ]]
			then
				local m_NoPartTableDisks=($(DisksWithoutPartitionTable Disks))
				if [[ -n "${m_NoPartTableDisks[@]}" ]]
				then
					local diskhave0000=($(TempArrayWithAmpersandHasHaveTexts ${#m_NoPartTableDisks[@]}))
					if [[ "${m_NoPartTableDisks[@]}" == "${Disks[@]}" ]]
					then
						dialog --yes-label "Back" --no-label "Set Table" --yesno "All selected ${diskhave0000[0]} does not contain a partition table. Set a Partition Table or go Back to the Disks Selection Menu?" 0 0
						case $? in
							0)
								PartitionDisk
								unset m_NoPartTableDisks
								;;
							1)
								unset m_NoPartTableDisks
								WritePartitionTable Disks
								EditDisk Disks
								;;
						esac
					elif [[ "${m_NoPartTableDisks[@]}" != "${Disks[@]}" ]]
					then
						local m_DisksWithPartTable=($(DiscardFromArray Disks m_NoPartTableDisks))
						local m_DisksTemp=("${Disks[@]}")
						m_DisksTemp=($(TempArrayWithAmpersand m_DisksTemp))
						local diskhave1111=($(TempArrayWithAmpersandHasHaveTexts ${#Disks[@]}))
						local m_NoPartTableDisksTemp=("${m_NoPartTableDisks[@]}")
						m_NoPartTableDisksTemp=($(TempArrayWithAmpersand m_NoPartTableDisksTemp))

						dialog --ok-label "Back" --cancel-label "Set Table" --extra-button --extra-label "Discard ${diskhave0000[0]}" --yesno "Selected ${diskhave0000[0]} ${m_NoPartTableDisksTemp[*]} does not contain a partition table. Set a Partition Table, Discard The ${diskhave0000[0]} and use ${diskhave1111[*]} ${m_DisksWithPartTable[*]} or go Back to The Disks Selection Menu" 0 0
						case $? in
							0)
								WritePartitionTable m_NoPartTableDisks
								EditDisk m_NoPartTableDisks
								unset m_NoPartTableDisks
								;;
							1)
								PartitionDisk
								unset m_NoPartTableDisks
								;;
							3)
								Disks=($(DiscardFromArray Disks m_NoPartTableDisks))
								dialog --msgbox "Discarded ${diskhave0000[*]} ${m_NoPartTableDisksTemp[*]}. Using ${diskhave1111[*]} ${m_DisksTemp[*]}" 0 0
								unset m_NoPartTableDisks m_NoPartTableDisksTemp m_DisksTemp diskhave1111 diskhave0000
								;;
						esac
					fi
				fi


        		#########################
				# dialog --yesno "Change an already set partition table?" 0 0
				# case $? in
				# 	0) WritePartitionTable Disks ;;
				# esac
				dialog --extra-button --extra-label "Mount" --ok-label "Back" --cancel-label "Edit" --yesno "Select \"Edit\" for Editting and then mounting the partitions of this disk or select \"Mount\" to only select, format and mount existing Linux filesystem/EFI/swap partitions" 0 0
				case $? in
					0) PartitionDisk ;;
					1)
						EditDisk Disks
						# DisksWithoutPartitionsPresent Disks
						# local DISKSWITHOUTPARTITIONSPRESENT_EXIT_CODE=$?
						# CheckEditMount Disks DISKSWITHOUTPARTITIONSPRESENT_EXIT_CODE
						# case $DISKSWITHOUTPARTITIONSPRESENT_EXIT_CODE in
						DisksWithoutPartitionsPresent Disks
						case $? in
						# case $DISKSWITHOUTPARTITIONSPRESENT_EXIT_CODE in
							0) CheckEditMount Disks DISKSWITHOUTPARTITIONSPRESENT_EXIT_CODE ;;
							1) MountViewPartitions Disks ;;
						esac
						unset DISKSWITHOUTPARTITIONSPRESENT_EXIT_CODE
						# unset DISKSWITHOUTPARTITIONSPRESENT_EXIT_CODE Disks
						;;
					3)
						DisksWithoutPartitionsPresent Disks
						CheckEditMount Disks $?
						# MountViewPartitions Disks
						;;
				esac
			fi
			;;
	esac
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


	Disks=($(IFS="";sort <<<${Disks[@]}))

	DisksTemp=("${Disks[@]}")
	DisksTemp=($(TempArrayWithAmpersand DisksTemp))
	disk=""
	DisksTempSize=${Disks[@]}
	NoPartDisks=()
	for (( i = 0; i < ${#DisksTempSize[@]}; i++ ))
	do
		DiskPartName=($(DiskPartInfoTemp "${Disks[$a]}" | awk '{ print $1 }'))
		if [[ -z "${DiskPartName[$a]}" ]]
		then
			NoPartDisks+=("${DiskPartName[$a]}")
		fi
	done
	unset disk

	if [[ -n "${NoPartDisks[@]}" ]]
	then
		local diskhave=($(TempArrayWithAmpersandHasHaveTexts ${#NoPartDisks}))
		local NoPartDisksTemp=("${NoPartDisks[@]}")
		NoPartDisksTemp=($(TempArrayWithAmpersand NoPartDisksTemp))
		dialog --yesno "${diskhave[0]} ${NoPartDisksTemp[*]} does not have any partitions. Edit the ${diskhave[0]}?" 0 0
		case $? in
			0) EditDisk NoPartDisks ;;
			1)
				DisksTempSize=${#Disks[@]}
				Disks=($(DiscardFromArray Disks NoPartDisks))
				dialog --msgbox "${diskhave[0]} ${NoPartDisksTemp[*]} $have been discarded. using ${diskhave[0]} ${Disks[*]}" 0 0
				;;
		esac
		unset NoPartDisksTemp
		unset diskhave
	fi
	unset DisksTempSize
	unset NoPartDisks

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
		if [[ -z ${DiskPartSizeTemp[@]} ]] && [[ -z ${DiskPartFsTypeTemp[@]} ]] && [[ -z ${DiskPartLabelTemp[@]} ]] && [[ -z ${DiskPartName[@]} ]]
	    then
	        continue
	    elif [[ -n ${DiskPartSizeTemp[@]} ]] && [[ -n ${DiskPartFsTypeTemp[@]} ]] && [[ -n ${DiskPartLabelTemp[@]} ]] && [[ -n ${DiskPartName[@]} ]]
    	then
	    	DiskPartFsTypeString=""
	    	for aa in "${DiskPartFsTypeTemp[@]}"
	    	do
	    		if [[ "$aa" =~ [1] ]]
	    		then
    				DiskPartFsType+=("$(echo "$DiskPartFsTypeString" | sed 's/\s$//g')")
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

			partition=($(dialog --cancel-label "Back" --column-separator "|" --title "Partition Mount Menu" --extra-button --extra-label "OK" --ok-label "Mount" --checklist "Partitions in /dev/${Disks[$a]}" 0 0 0 "${DiskPartListInfo[@]}" 3>&1 1>&2 2>&3))
			# 0 - ok
			# 1 - back
			# 3 - mount

			case $? in
				0)
					SelectedPartitionsTemp+=("${partition[@]}")
					for (( c = 0; c < ${#SelectedPartitionsTemp[@]}; c++ ))
					do
						for (( d = 0; d < ${#DiskPartName[@]}; d++ ))
						do
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
					;;

				1)	PartitionDisk ;;

				3)
					disk=""
					SelectedPartitionsTemp+=("${partition[@]}")
					if [[ -z "${SelectedPartitionsTemp[@]}" ]] && [[ -z "${partition[@]}" ]]
					then
						DiscardDisks=("${Disks[@]:$a}")
					elif [[ -z "${SelectedPartitionsTemp[@]}" ]] && [[ -n "${partition[@]}" ]]
					then
						a=$((a+1))
						DiscardDisks=("${Disks[@]:$a}")
					fi

					if [[ ${#DiscardDisks[@]} -eq 1 ]] && [[ ${#Disks[@]} -eq 1 ]]
					then
						dialog --yes-label "OK" --no-label "Back" --yesno "No Disk/Partiton selected for insallation. Please Select a Disk and few Partitions" 0 0
						unset DiscardDisks
						PartitionDisk
					elif [[ ${#DiscardDisks[@]} -eq 1 ]] && [[ ${#Disks[@]} -gt 1 ]]
					then
						disk="disk"
						dialog --yes-label "OK" --no-label "Back" --yesno "Discarding $disk ${DiscardDisks[*]}" 0 0
						unset DiscardDisks
						break
					# elif [[ ${#DiscardDisks[@]} -eq ${#Disks[@]} ]]
					elif [[ "${DiscardDisks[@]}" == "${Disks[@]}" ]]
					then
						dialog --msgbox "Discarding all selected Disks. Please Select a Disk from the Disk Selection Menu" 0 0
						unset DiscardDisks
						PartitionDisk
					elif [[ ${#DiscardDisks[@]} -gt 1 ]] && [[ ${#DiscardDisks[@]} -ne ${#Disks} ]]
					then
						DiscardDisksTemp=($(TempArrayWithAmpersand DiscardDisks))
						dialog --yes-label "OK" --no-label "Back" --yesno "Discarding $disk ${DiscardDisksTemp[*]}" 0 0
						unset DiscardDisksTemp
						break
					# elif [[ ${#DiscardDisks[@]} -gt 1 ]] && [[ ${#DiscardDisks[@]} -eq ${#Disks[@]} ]]
					elif [[ ${#DiscardDisks[@]} -gt 1 ]] && [[ "${DiscardDisks[@]}" == "${Disks[@]}" ]]
					then
						dialog --yes-label "Select Disk" --no-label "Select Partition" --yesno "No disk or partition selected for installation. Select Disks or Select Partitions from already Selected Disks?\n\nSelected Disks: ${Disks[*]}" 0 0
						case $? in
							0) PartitionDisk ;;
							1) MountViewPartitions Disks ;;
						esac
					fi
					;;
			esac
		fi
		DiskPartListInfo=()
		DiskPartSizeTemp=()
		DiskPartFsType=()
		DiskPartLabel=()
	done

	# total_parts=${#fat32_efi_parts[@]}+${#linux_fs_ext4_parts[@]}+${#swap_parts[@]}+${#home_parts[@]}
	total_parts=$(($fat32_efi_part_count+$linux_fs_ext4_part_count+$swap_part_count+$home_part_count))


	if [[ $swap_part_count -eq 0 ]] && [[ $home_part_count -eq 0 ]] && [[ $fat32_efi_part_count -gt 1 ]] && [[ $linux_fs_ext4_part_count -gt 1 ]] && [[ $swap_part_count -eq 1 ]]
	then
		dialog --yesno "no home or swap partitions detected. Continue without them?" 0 0
		case $? in
			0)
				# ConfirmMounts SelectedPartitionsMountedText
				echo "ConfirmMounts SelectedPartitionsMountedText"
				case $? in
					# 0) MountPartitions SelectedPartitionsMountedText MountPoints MountBlockDev ;;
					0) echo "MountPartitions" ;;
					1) PartitionDisk ;;
				esac
				;;
			1) MountViewPartitions Disks ;;
		esac

	# elif ( [[ ${#fat32_efi_parts[@]} -gt 1 ]] && [[ ${#linux_fs_ext4_parts[@]} -gt 1 ]] ) || [[ $total_parts -gt 4 ]]
	elif [[ $fat32_efi_part_count -gt 1 ]] && [[ $linux_fs_ext4_part_count -gt 1 ]]
	then
		dialog --msgbox "multiple essential linux partitions detected (boot and ext4). please select one partition for each filesystem" 0 0
		MountViewPartitions Disks
	elif [[ $fat32_efi_part_count -gt 1 ]]
	then
		dialog --msgbox "multiple boot partitions detected. please select one" 0 0
		MountViewPartitions Disks
	elif [[ $linux_fs_ext4_part_count -gt 1 ]]
	then
		dialog --msgbox "multiple linux filesystems detected. please select one" 0 0
		MountViewPartitions Disks
	elif [[ $total_parts -eq 0 ]]
	then
		dialog --msgbox "no partitions selected. please select an EFI and a linux filesystem partition (mandatory). Select a few optional partitions as well (if needed or wanted but not necessary)" 0 0
		local diskhave=($(TempArrayWithAmpersandHasHaveTexts ${#DisksTemp[@]}))
		local DisksTemp=("${Disks[@]}")
		DisksTemp=($(TempArrayWithAmpersand DisksTemp))
		dialog --no-label "Continue" --yes-label "Disk Menu" --yesno "Using ${diskhave[0]} ${DisksTemp[*]}. Continue to use the ${diskhave[0]} or go back to the Disk Selection Menu?" 0 0
		case $? in
			0) PartitionDisk ;;
			1) MountViewPartitions Disks ;;
		esac
		unset temp
		unset DisksTemp
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
		case $? in
			0) echo "MountPartitions" ;;
			# 0) ConfirmMounts SelectedPartitionsMountedText ;;
			# 0) MountPartitions SelectedPartitionsMountedText MountPoints MountBlockDev ;;
			1) MountViewPartitions Disks;;
		esac
		# DiskPartListInfo=()

	elif [[ $home_part_count -eq 0 ]]
	then
		dialog --yesno "no home partition detected. continue without home partition?" 0 0
		case $? in
			0) echo "ConfirmMounts SelectedPartitionsMountedText" ;;
			# 0) ConfirmMounts SelectedPartitionsMountedText ;;
			1) PartitionDisk ;;
		esac
	elif [[ $linux_fs_ext4_part_count -eq 0 ]] && [[ $fat32_efi_part_count -eq 0 ]]
	then
		dialog --msgbox "no boot and system partitions detected. system cannot be installed." 0 0
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
	elif mountpoint /mnt &>/dev/null
	then
		# nvidia linux nvlink/capabilities/fabric-mgmt 0
		packages=()
		packages_temp=(base base-devel devel linu{x,x-{docs,headers}} grub efi{var,bootmgr} dkms broadcom-dkms-wl-dkms xf86-input-{libinput,synaptics} xf86-video-fbdev)
		for i in "${packages_temp[@]}"
		do
			packages+=("$i")
		done
		unset packages_temp

		cpu_vendor=$(cat /proc/cpuinfo | grep vendor | uniq | awk '{print $3}')

		amd_gpu=()
		amd_gpu_temp=(xf86-video-{amdgpu,ati} lib32-{amdvlk,opencl-mesa} opencl-mesa amdvlk)
		for i in "${packages_temp[@]}"
		do
			amd_gpu+=("$i")
		done
		unset amd_gpu_temp


		intel_gpu=()
		intel_gpu_temp=(xf86-video-intel libva-intel-driver lib32-{libva-intel-driver,vulkan-intel} vulkan-intel intel-graphics-compiler)
		for i in "${packages_temp[@]}"
		do
			intel_gpu+=("$i")
		done
		unset intel_gpu_temp


		nvidia_gpu=()
		nvidia_gpu_temp=(ffnvcodec-headers libvdpau opencl-nvidia xf86-video-nouveau lib32-{libvdpau,nvidia-utils,opencl-nvidia} nvidia-{dkms,lts,prime,settings,utils})
		for i in "${packages_temp[@]}"
		do
			nvidia_gpu+=("$i")
		done
		unset nvidia_gpu_temp



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

		case $? in
			0)
				# editors="${editors[@]}"
				if [[ $editors == "" ]]
				then
					packages="${packages[@]}"
				else
					packages="${packages[@]} ${editors[@]}"
				fi
				;;
			1) MainMenu "Install Arch *" ;;
			3) packages="${packages[@]}"; break ;;
			# 3) packages="${packages[@]}"; break ;;
		esac






		dialog --msgbox "packages that will be installed:\n${packages[*]}" 0 0

		: '
		pacstrap /mnt "$packages" | GuageMeter "Installing arch linux packages" 1
		# pacstrap /mnt "$packages"

		case ${PIPESTATUS[0]} in
			0) genfstab "/mnt/" > "/mnt/etc/fstab" ;;
			*) dialog --msgbox "failed to install packages via pacstrap"
		esac
		'
		echo ""
		case $? in
			0)
				dialog --msgbox "Created fstab entry. you can generate the fstab of your disk by \"executing genfstab -U /mnt > /mnt/etc/fstab\" (i.e. if anythin went wrong with the fstab entry)" 0 0
				bootloaderid="$(dialog --inputbox "Bootloader ID - Input Any Text" 0 0)"
				# grub-install -v --boot-directory="/mnt/boot" --bootloader-id "$bootloaderid" --efi-directory="/mnt/boot" --recheck --removable --target x86_efi-efi
				echo "grub-install -v --boot-directory=\"/mnt/boot\" --bootloader-id \"$bootloaderid\" --efi-directory=\"/mnt/boot\" --recheck --removable --target x86_efi-efi"
				case $? in
					0) dialog --msgbox "Grub successfully installed" 0 0;MainMenu "Install Arch *" ;;
					1) dialog --msgbox "could not install grub-bootloader. you execute \'grub-install --help | less\' on one tty and run \'grub-install <options>\' on another tty. \n\nDO NOT USE THE \'--force\' option.You can open tty's by pressing ctrl+alt+<F1>-<F6> with each function key corresponding to their tty id\n\n Go back to the Main Menu or exit to the tty?" ;;
				esac
				;;
			1) dialog --msgbox "could not install Arch." 0 0 ;;
		esac
	fi
}














Repo_Enable(){
	dialog --backtitle "Written by c2700" --yesno "enable \"multilib\" repo for packages with support for multiple architectures?" 5 80
	case $? in
		0)
			# sed '94s/\#\[/"["' /etc/pacman.conf
			# sed '95s/\#\[/""' /etc/pacman.conf
			dialog --backtitle "Written by c2700" --msgbox "\"multilib\" repo has been enabled. you can add, remove, disable or enable repos by editing the \"/etc/pacman.conf\" file" 0 0
			;;
		1)
			dialog --backtitle "Written by c2700" --no-label "exit" --yes-label "continue installation" --yesno "multilib repo not enabled. To enable it restart the script or uncomment lines 94 and 95 in file \"/etc/pacman.conf\"" 6 63
			case $? in
				0) exit ;;
				1) echo "" ;;
			esac
	esac
}





MainMenu(){
	# set -xETt
	# $1 - menu option item

	clear
    # check if dialog is installed
	ls /usr/bin/dialog &>/dev/null
	case $? in
		0)
			echo ""
			;;
		1)
			echo -e "dialog not installed.\n"
			read -s -n1 -p "press any key to install the git provided dialog package "
			pacman -Uvd --noconfirm "$(ls dialog*)"
			case $? in
				0)
					dialog --msgbox "installed dialog" 0 0
					;;
				1)
					clear
					echo -e "\n\ndialog could not be installed"
					# echo -e "\n\ndialog could not be installed.\n\nPlease install provided dialog packages by typing \"pacman -Uvd <package name>\" with or without the \"--noconfirm\" argument.\n\ncurrent directory:\n$(pwd)\n\npackages in this directory:\n$(ls *.pkg*).\n\n\nexiting...\n\n"
					exit
					;;
			esac
			;;
	esac


	menuopt=("Partition Disk **" "format/Partition/select Hard Disks and mount partitions")
	menuopt+=("Configure Network **" "Check connectivity and connect to a network")
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

# trap '' 2
# Repo_Enable
MainMenu "Partition Disk **" 3>&1 1>&2 2>&3
