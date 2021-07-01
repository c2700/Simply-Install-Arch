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

	local UnsetArray=$1[@]
	UnsetArray=(${!UnsetArray})

	local RefArray=$2[@]
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
				case $? in
					0) iwd_mngr ;;
					1) ConfNet ;;
				esac
			fi
		done
	fi
}

iwd_mngr(){

	local wireless_dev=""

	systemctl enable --now iwd

	#select wireless card
	local wireless_devs=($(iwctl station list | grep -iv 'name\|devices\|\-' | awk '{print $1}'))
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
		wireless_dev="$(dialog --menu "Wireless Card Selection Menu" 0 0 0 "${wireless_cards[@]}" 3>&1 1>&2 2>&3)"
	fi

	clear
	iwctl station "$wireless_dev" scan
	clear
	iwctl station "$wireless_dev" get-networks | more && read -p "Enter Wireless network to connect to : " SSID
	dialog --yesno "view wireless passphrase in plaintext as you enter?" 0 0
	case $? in
		0)
			# read -p "$SSID password: " pass
			iwctl --passphrase $pass station $wireless_dev connect $SSID
			iw_reconnect $? $wireless_dev $SSID "$(read -p "$SSID password: ")"
			;;
		1)
			iwctl station $wireless_dev connect $SSID
			iw_reconnect $? $wireless_dev $SSID
			;;
	esac
}


nm_mngr(){
	systemctl enable --now NetworkManager
	nmcli networking on
	nmcli radio wifi on

	case $? in
		0)
			nmcli device wifi rescan
				clear
				dialog --msgbox "press 'q' to exit the upcoming wifi list" 0 0
				nmcli device wifi list && read -p "Enter SSID to connect to: " wifi_name
				nmcli device wifi connect "$wifi_name" -a
				case $? in
					1)
						# for (( reconnect = "n"; reconnect != "n" ;))
						for (( reconnect="n"; reconnect == "y" ;))
						do
							nmcli device wifi list && read -p "Enter SSID to connect to: " wifi_name
							nmcli device wifi connect "$wifi_name" -a
							read -p "rescan and connect to another ssid? [y/n]" reconnect
						done
						;;
				esac
			;;
		1)
			local con_name
			con_name=$(dialog --inputbox "set a name for this wired connection" 0 0 3>&1 1>&2 2>&3)
			nmcli connection add con-name "$con_name" type ethernet autoconnect yes
			;;
	esac
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
		dialog --msgbox "no networkmanagers available. Local networkmanager package will be installed" 0 0
		pacman -Uvd --noconfirm --needed "$(ls networkmanager*)"
		dialog --msgbox "enabling NetworkManager" 0 0
		nmtui
		# # nm_mngr
		MainMenu "Configure Network"
	fi

	local NM
	NM=$(dialog --cancel-label "BACK" --menu "Availble Network Managers" 0 0 0  "${NMList[@]}" 3>&1 1>&2 2>&3)

	case $? in
		0)
			case $NM in
				"wifi-menu")
					# "${NM}"
					wifi-menu
					;;
				"networkmanager")
					# # nm_mngr
					# nmtui
					dialog --msgbox "networkmanager used" 0 0
					MainMenu "Configure Network **"
					;;
				"iwd")
					# iwd_mngr
					dialog --msgbox "iwd used" 0 0
					MainMenu "Configure Network **"
					;;
			esac
			;;
		1) MainMenu "Configure Network **" ;;
		255) ConfNet ;;
	esac
}





######################################### Disk Editing, formatting and mounting ############################################

# confirm and mount selected partitions
ConfirmMounts(){

	local m_MountDisksArgs=$1[@]
	local m_MountDisksTemp=("${!m_MountDisksArgs}")
	unset m_MountDisksArgs

	local m_MountPartitionsTextsArgs=$2[@]
	local m_MountPartitionsTextsTemp=("${!m_MountPartitionsTextsArgs}")
	unset m_MountPartitionsTextsArgs

	local linuxfs=""

	dialog --yes-label "Change filesystem" --no-label "Use Default" --yesno "Use default ext4 for linux filesystem or use a different filesystem?" 0 0
	case $? in
		0)
			local linuxfs_list=()
			linuxfs_list+=("ext4" "")
			linuxfs_list+=("ext3" "")
			linuxfs_list+=("ext2" "")
			linuxfs_list+=("btrfs" "")
			linuxfs_list+=("xfs" "")
			linuxfs_list+=("zfs" "")
			local linuxfschange="$(dialog --no-tags --menu "Select filesystem to use as linux filesystem" 0 0 0 "${linuxfs_list[@]}" 3>&1 1>&2 2>&3)"
			case $? in
				0)
					if [[ "$linuxfs" == "$linuxfschange" ]]
					then
						dialog --msgbox "default linux filesystem ext4 has not been changed. Using ext4 filesystem" 0 0
					elif [[ "$linuxfs" != "$linuxfschange" ]]
					then
						linuxfs="$linuxfschange"
						dialog --msgbox "Using $linuxfs filesystem" 0 0
					fi
					;;
				1)
					linuxfs="$linuxfschange"
					dialog --msgbox "Using default ext4 linux filesystem" 0 0
					;;
			esac
			;;
		1)
			linuxfs="ext4"
			dialog --msgbox "Using default ext4 linux filesystem" 0 0
			;;
	esac
	unset linuxfs_list

	# declare -A MountParts
	local MountParts=()
	local MountPartsTexts=()

	for k in ${m_MountDisksTemp[@]}
	do
		local MountPartsString="/dev/$k\n"
		for l in ${m_MountPartitionsTextsTemp[@]}
		do
			local partsize="$(lsblk "/dev/$l" -dlno size | awk '{ sub("[mM]"," MB");sub("[gG]"," GB");print 0; }')"
			local partfsformat="$(lsblk "/dev/$l" -dlno fstype,fsver | awk '{ print $1" "$2 }' | sed 's/vfat FAT32/FAT32/g;s/ext4 1.0/ext4/g;s/swap 1/swap/g')"
			local m_parttypename="$(lsblk "/dev/$l" -dlno parttypename)"
			local partlabel="$(lsblk "/dev/$l" -dlno partlabel)"

			local m_Tempdisk="$(echo "$l" | grep -i "$k")"

			if [[ ${#m_MountDisksTemp[@]} -eq 1 ]]
			then
				if [[ "$m_Tempdisk" == "$k" ]]
				then
					MountPartsString="  \`-/dev/$l --> $partsize --> $partlabel --> $m_parttypename"
					# MountPartsString="/dev/$k\n  \`-/dev/$l --> $partsize --> $partlabel --> $m_parttypename"
					# MountPartsString="/dev/$k  \`-/dev/$l --> $partsize --> $partlabel --> $m_parttypename"
					if [[ -n $partfsformat ]]
					then
						MountPartsString+=" --> *$partfsformat"
						if [[ "$m_parttypename" == "EFI System" ]] || [[ "$m_parttypename" == "EFI (FAT-12/16/32)" ]]
						then
							MountPartsString+=" --> /boot"
						elif [[ $m_parttypename == "Linux filesystem" ]]
						then
							MountPartsString+=" --> /\n"
						elif [[ $m_parttypename == "Linux swap" ]]
						then
							MountPartsString+=" --> (mounted as swap)\n"
						elif [[ $m_parttypename == "Linux home" ]]
						then
							MountPartsString+=" --> /home\n"
						fi
					elif [[ -z $partfsformat ]]
					then
						if [[ "$m_parttypename" == "EFI System" ]] || [[ "$m_parttypename" == "EFI (FAT-12/16/32)" ]]
						then
							MountPartsString+=" --> /boot\n"
						elif [[ $m_parttypename == "Linux filesystem" ]]
						then
							MountPartsString+=" --> /\n"
						elif [[ $m_parttypename == "Linux swap" ]]
						then
							MountPartsString+=" --> +swap --> (mounted as swap)\n"
						elif [[ $m_parttypename == "Linux home" ]]
						then
							MountPartsString+=" --> +$linuxfs --> /home\n"
						fi
					fi
					# MountParts["$k"]="$MountPartsString\n"
					MountParts+=("$MountPartsString\n")
				fi
			elif [[ ${#m_MountDisksTemp[@]} -gt 1 ]]
			then
				if [[ "$m_Tempdisk" == "$k" ]]
				then
					if [[ "$i" == ${m_MountPartitionsTextsTemp[0]} ]] || [[ "$i" != ${m_MountPartitionsTextsTemp[-1]} ]]
					then
						MountPartsString="  \|-/dev/$l --> $partsize --> $partlabel --> $m_parttypename\n"
						# MountPartsString="/dev/$k\n  \|-/dev/$l --> $partsize --> $partlabel --> $m_parttypename\n"
						# MountPartsString="  \|-/dev/$l --> $partsize --> $partlabel --> $m_parttypename\n"
					elif [[ "$i" == ${m_MountPartitionsTextsTemp[-1]} ]]
					then
						MountPartsString="/dev/$k\n  \`-/dev/$l --> $partsize --> $partlabel --> $m_parttypename\n"
						# MountPartsString="  \`-/dev/$l --> $partsize --> $partlabel --> $m_parttypename\n"
					fi

					if [[ -n $partfsformat ]]
					then
						MountPartsString+=" --> *$partfsformat"
						if [[ "$m_parttypename" == "EFI System" ]] || [[ "$m_parttypename" == "EFI (FAT-12/16/32)" ]]
						then
							MountPartsString+=" --> /boot\n"
						elif [[ $m_parttypename == "Linux filesystem" ]]
						then
							MountPartsString+=" --> /\n"
						elif [[ $m_parttypename == "Linux swap" ]]
						then
							MountPartsString+=" --> (mounted as swap)\n"
						elif [[ $m_parttypename == "Linux home" ]]
						then
							MountPartsString+=" --> /home\n"
						fi
					elif [[ -z $partfsformat ]]
					then
						if [[ "$m_parttypename" == "EFI System" ]] || [[ "$m_parttypename" == "EFI (FAT-12/16/32)" ]]
						then
							MountPartsString+=" --> +fat32 --> /boot\n"
						elif [[ $m_parttypename == "Linux filesystem" ]]
						then
							MountPartsString+=" --> +$linuxfs --> /\n"
						elif [[ $m_parttypename == "Linux swap" ]]
						then
							MountPartsString+=" --> +swap --> (mounted as swap)\n"
						elif [[ $m_parttypename == "Linux home" ]]
						then
							MountPartsString+=" --> +$linuxfs --> /home\n"
						fi
					fi
					# MountParts["$k"]="$MountPartsString\n"
					MountParts+=("$MountPartsString\n")
				fi
			fi
			unset m_Tempdisk
		done
		unset MountPartsString
	done
	unset m_MountDisksTemp

	dialog --ok-label "Back" --cancel-label "Format" --extra-button --extra-label "Re-Format" --title "partition mount confirmation" --yesno "1) +Format - Will format the partition with specified filesystem format. Reformatting will\n   not apply here.\n2) *Format - Will reformat the partition with selected or changed filesystem format wiping\n   the partition.\n\nFormat:\n   Partition --> Size --> Partition Label --> Filesystem --> (+|*)Format --> MountPoint\n\n${MountParts[*]}" 20 95
	case $? in
		0)
			unset MountParts
			PartitionDisk ;;
		1)
			unset MountParts
			dialog --yesno "Wipe partitions that will be formatted with selected filesystem?" 0 0
			if [[ $? -eq 0 ]]
			then
				for g in ${m_MountPartitionsTextsTemp[@]}
				do
					local partfsformat2="$(lsblk "/dev/$l" -dlno fstype,fsver | awk '{ print $1" "$2 }')"
					if [[ -z $partfsformat2 ]]
					then
						echo -e "wiped /dev/\$g"
					elif [[ -n $partfsformat2 ]]
					then
						unset partfsformat2
						continue
					fi
					unset partfsformat2
				done
			fi

			# make fs and mount the partitions
			for g in ${m_MountPartitionsTextsTemp[@]}
			do
				local partfsformat2="$(lsblk "/dev/$l" -dlno fstype,fsver | awk '{ print $1" "$2 }')"
				if [[ -z $partfsformat2 ]]
				then
					FormatPartition "$g" "$linuxfs" # | GuageMeter \"Formatting partition /dev/\$Partition with \$fsformat\" 1"
					MountPartition "$g"
				elif [[ -n $partfsformat2 ]]
				then
					unset partfsformat2
					continue
				fi
				
				unset partfsformat2
			done
			dialog --msgbox "formatted partitions with appropriate fs formats and mounted them" 0 0
			genfstab "/mnt/" > "/mnt/etc/fstab"
			dialog --msgbox "Created fstab entry. you can generate the fstab of your disk by executing \"genfstab -U /mnt > /mnt/etc/fstab\" (if anything went wrong with the fstab entry i.e.)" 0 0
			unset m_MountPartitionsTextsTemp linuxfs
			;;
		3)
			dialog --yesno "Wipe all partitions before formatting empty partitions and reformatting partitions with existing filesystems?" 0 0
			if [[ $? -eq 0 ]]
			then
				for g in ${m_MountPartitionsTextsTemp[@]}
				do
					echo -e "wiped /dev/\$g"
				done
			fi
			dialog --msgbox "Wiped all selected partitions" 0 0

			for g in ${m_MountPartitionsTextsTemp[@]}
			do
				local partfsformat2="$(lsblk "/dev/$l" -dlno fstype,fsver | awk '{ print $1" "$2 }')"
				if [[ -z $partfsformat2 ]]
				then
					FormatPartition "$g" "$linuxfs" # | GuageMeter \"Formatting partition /dev/\$Partition with \$fsformat\" 1"
					MountPartition "$g"
				elif [[ -n $partfsformat2 ]]
				then
					FormatPartition "$g" "$linuxfs" # | GuageMeter \"Re-Formatting partition /dev/\$Partition with \$fsformat\" 1"
					MountPartition "$g"
				fi
				unset partfsformat2
			done
			dialog --msgbox "formatted partitions with appropriate fs formats and mounted them" 0 0
			genfstab "/mnt/" > "/mnt/etc/fstab"
			dialog --msgbox "Created fstab entry. you can generate the fstab of your disk by executing \"genfstab -U /mnt > /mnt/etc/fstab\" (if anything went wrong with the fstab entry i.e.)" 0 0
			unset m_MountPartitionsTextsTemp linuxfs
			;;
	esac
}

FormatPartition(){
	local Partition=$1
	local fsformat=$2
	local m_parttypename="$(lsblk "/dev/$l" -dlno parttypename)"

	if [[ "$m_parttypename" == "Linux filesystem" ]] || [[ "$m_parttypename" == "Linux home" ]]
	then
		printf "y\n" | mkfs.$fsformat "/dev/$Partition" &>/dev/null | GuageMeter "Formatting partition /dev/$Partition with $fsformat" 1
		# echo -e "mkfs.\$fsformat \"/dev/\$Partition\" | GuageMeter \"Formatting partition /dev/\$Partition with \$fsformat\" 1"
		# read -p "mkfs.fsformat /dev/partition" -n1
		# printf "y\n" | mkfs.$fsformat "/dev/$Partition" | GuageMeter "Formatting partition /dev/$Partition with $fsformat" 1
	elif [[ "$m_parttypename" == "EFI System" ]] || [[ "$m_parttypename" == "EFI (FAT-12/16/32)" ]]
	then
		printf "y\n" | mkfs.fat -F32 "/dev/$P &>/dev/nullartition" | GuageMeter "Formatting partition /dev/$Partition with $fsformat" 1
		# echo "mkfs.fat -F32 \"/dev/\$Partition\" | GuageMeter \"Formatting partition /dev/\$Partition with \$fsformat\" 1"
		# read -p "mkfs.fat -F32 /dev/partition" -n1
		# printf "y\n" | mkfs.fat -F32 "/dev/$Partition" | GuageMeter "Formatting partition /dev/$Partition with $fsformat" 1
	elif [[ "$m_parttypename" == "Linux swap" ]]
	then
		printf "y\n" | mkswap "/dev/$Partition" &>/dev/null | GuageMeter "creating swap filesystem on partition /dev/$Partition" 1
		# echo -e "mkswap \"/dev/\$Partition\" | GuageMeter \"creating swap filesystem on p\artition /dev/\$Partition\" 1"
		# read -p "mkswap /dev/partition" -n1
		# printf "y\n" | mkswap "/dev/$Partition" | GuageMeter "creating swap filesystem on partition /dev/$Partition" 1
	fi

	unset Partition fsformat m_parttypename
}

MountPartition(){
	local Partition=$1
	local m_parttypename="$(lsblk "/dev/$l" -dlno parttypename)"
	local partfsformat="$(lsblk "/dev/$l" -dlno fstype,fsver | awk '{ print $1" "$2 }' | sed 's/vfat FAT32/FAT32/g;s/ext4 1.0/ext4/g;s/swap 1/swap/g')"
	local partfsformat2="$(lsblk "/dev/$l" -dlno fstype,fsver | awk '{ print $1" "$2 }')"
	if [[ "$m_parttypename" == "Linux filesystem" ]]
	then
		case $partfsformat in
			# "ext2"|"ext3"|"ext4"|"btrffs"|"xfs"|"zfs") echo "mount \"/dev/\$Partition\" /mnt/" ;;
			"ext2"|"ext3"|"ext4"|"btrffs"|"xfs"|"zfs") mount "/dev/$Partition" /mnt/ ;;
		esac
	elif [[ "$m_parttypename" == "Linux home" ]]
	then
		# echo "mount \"/dev/\$Partition\" /mnt/home/"
		mount "/dev/$Partition" /mnt/home/
	elif ([[ "$m_parttypename" == "EFI System" ]] || [[ "$m_parttypename" == "EFI (FAT-12/16/32)" ]]) && [[ "$partfsformat" == "FAT32" ]] && [[ "$partfsformat2" == "vfat FAT32" ]]
	then
		mount "/dev/$Partition" /mnt/boot/
	elif [[ "$m_parttypename" == "Linux swap" ]] || [[ "$partfsformat" == "swap" ]]
	then
		# echo "swapon \"/dev/\$Partition\""
		swapon "/dev/$Partition"
	fi
	unset Partition fsformat m_parttypename
}

# Disk Info
DiskListTemp(){
	local Disk=$1
	if [[ -n "$Disk" ]]
	then
		lsblk "/dev/$Disk" -dno name,size,pttype,vendor,model | grep -iv 'loop\|sr[0-9]*' | sed -E 's/\s{8}/ none   /g'
	elif [[ -z $1 ]]
	then
		lsblk -dno name,size,pttype,vendor,model | grep -iv 'loop\|sr[0-9]*' | sed -E 's/\s{8}/ none   /g'
	fi
}

# Partition Info
DiskPartInfoTemp(){
	if [[ -z $1 ]]
	then
		lsblk -nlo name,size,partlabel,parttypename | grep -ie '[has]d[a-z][0-9]\|linux filesystem\|efi\|swap\|linux.*home\|^Linux$' | sed -E 's/\s{13}/  /g' | grep -iv 'microsoft\|Windows'
	else
		lsblk /dev/"$1" -nlo name,size,partlabel,parttypename | grep -ie '[has]d[a-z][0-9]\|linux filesystem\|efi\|swap\|linux.*home\|Windows recovery environment' | grep -i 'Microsoft Basic data\|Microsoft reserved\|' | sed -E 's/\s{13}/  /g' | grep -iv 'microsoft\|Windows'
	fi
}

# Partition Info (used for extracting partition label)
DiskPartTypeName(){
	if [[ -z $1 ]]
	then
		lsblk -nlo name,size,parttypename | grep -ie '[has]d[a-z][0-9]\|linux filesystem\|efi\|swap\|linux.*home' | sed -E 's/\s{13}/  /g' | grep -iv 'microsoft\|Windows\|Basic data partition'
	else
		lsblk /dev/"$1" -nlo name,size,parttypename | grep -ie '[has]d[a-z][0-9]\|linux filesystem\|efi\|swap\|linux.*home\|Windows recovery environment' | grep -i 'Microsoft Basic data\|Microsoft reserved\|' | sed -E 's/\s{13}/  /g' | grep -iv 'microsoft\|Windows\|Basic data partition'
	fi
}

# Check if disks have been edited, edit the array containing disks and then go to the partition viewer
CheckEditMount(){
	local m_DisksArgs=$1[@]
	local m_Disks=${!m_DisksArgs}
	unset m_DisksArgs

	local PREVIOUS_FUNC_EXIT_CODE=$2

	local m_NoPartsDisks=(${m_Disks[@]})
	m_NoPartsDisks=($(DisksWithoutPartitions m_NoPartsDisks))

	local m_DiskParts=(${m_Disks[@]})
	m_DiskParts=($(DisksWithPartitions m_DiskParts))

	case $PREVIOUS_FUNC_EXIT_CODE in
		0) MountViewPartitions m_Disks ;;
		1)
			local m_NoPartsDisksTemp=("${m_NoPartsDisks[@]}")
			m_NoPartsDisksTemp=($(TempArrayWithAmpersand m_NoPartsDisksTemp))
			local diskhave=($(TempArrayWithAmpersandHasHaveTexts ${#m_NoPartsDisks[@]}))

			local m_DisksTemp=("${m_Disks[@]}")
			m_DisksTemp=($(TempArrayWithAmpersand m_Disks))
			local diskhave0=($(TempArrayWithAmpersandHasHaveTexts ${#m_Disks[@]}))

			local m_DiskPartsTemp=($(TempArrayWithAmpersand m_DiskParts))
			local diskhave12=($(TempArrayWithAmpersandHasHaveTexts ${#m_DiskParts[@]}))

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
							0) MountViewPartitions m_Disks ;;
							1) CheckEditMount m_Disks $DISKSWITHOUTPARTITIONSPRESENT_EXIT_CODE ;;
						esac
						;;
				esac

			elif [[ "${m_NoPartsDisks[@]}" != "${m_Disks[@]}" ]]
			then
				dialog --ok-label "Back" --cancel-label "Edit" --extra-button --extra-label "Discard ${diskhave[0]}" --yesno "${diskhave[0]} ${m_NoPartsDisksTemp[*]} have not been edited. Edit ${diskhave[0]} ${m_NoPartsDisksTemp[*]}, go back to the Disk Selection Menu or Discard ${diskhave[0]} ${m_NoPartsDisksTemp[*]} and use ${diskhave12[0]} ${m_DiskParts[*]}?" 0 0
				case $? in
					0) PartitionDisk ;;
					1)
						EditDisk m_NoPartsDisks
						DisksWithoutPartitionsPresent m_Disks
						local DISKSWITHOUTPARTITIONSPRESENT_EXIT_CODE=$?
						case $DISKSWITHOUTPARTITIONSPRESENT_EXIT_CODE in
							0) MountViewPartitions m_Disks ;;
							1) CheckEditMount m_Disks $DISKSWITHOUTPARTITIONSPRESENT_EXIT_CODE ;;
						esac
						;;
					3)
						m_Disks=($(DiscardFromArray m_Disks m_NoPartsDisks))
						dialog --msgbox "Discarded ${diskhave0[0]}. Using ${diskhave[0]} ${m_Disks[*]}" 0 0
						MountViewPartitions m_Disks
						;;
				esac
			fi
			;;
		
	esac
}

# check if disk has a partition table
IsPartitionTablePresent(){
	local m_disksArgs="$1"
	# local m_disksArgs=$1[@]
	# local m_Disks=("${!m_disksArgs}")
	# unset m_disksArgs

	local m_parttable="$(DiskListTemp "$m_disksArgs" | awk '{ print $3 }')"
	if [[ "$m_parttable" == "none" ]]
	then
		return 1
	elif [[ "$m_parttable" != "none" ]]
	then
		return 0
	fi
}

# Return disks without a partition table
DisksWithoutPartitionTable(){
	local m_disksArgs=$1[@]
	local m_Disks=(${!m_disksArgs})
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

	for i in ${m_Disks[@]:$a}
	do
		IsPartitionTablePresent "$i"
		case $? in
			0) continue ;;
			1) m_NoPartTableDisks+=("$i") ;;
		esac
	done
	echo "${m_NoPartTableDisks[@]}"
}

# check if disk has partitions
DisksWithoutPartitionsPresent(){
	local DisksArgs=$1[@]
	# local Disks=(${!DisksArgs})
	local Disks=("${!DisksArgs}")
	unset DisksArgs

	local m_NoPartsDisks=""

	for i in ${Disks[@]}
	do
		local m_check=($(DiskPartInfoTemp "$i" | awk '{ print $1 }'))
		if [[ -z "${m_check[@]}" ]]
		then
			m_NoPartsDisks="$i"
			break
		fi
	done

	if [[ -n "$m_NoPartsDisks" ]]
	then
		unset m_NoPartsDisks
		return 1
	elif [[ -z "$m_NoPartsDisks" ]]
	then
		unset m_NoPartsDisks
		return 0
	fi
}

# Return disks not containing partitions
DisksWithoutPartitions(){
	local DisksArgs=$1[@]
	local Disks=("${!DisksArgs}")
	unset DisksArgs

	local m_NoPartsDisks=()
	for i in ${Disks[@]}
	do
		local m_check=($(DiskPartInfoTemp "$i" | awk '{ print $1 }'))
		if [[ -z ${m_check[@]} ]]
		then
			m_NoPartsDisks+=("$i")
		fi
		unset m_check
	done
	echo "${m_NoPartsDisks[@]}"
}

# Return disks containing partitions
DisksWithPartitions(){
	local DisksArgs=$1[@]
	local Disks=("${!DisksArgs}")
	unset DisksArgs

	local m_PartsDisks=()
	for i in ${Disks[@]}
	do
		local m_check=($(DiskPartInfoTemp "$i" | awk '{ print $1 }'))
		if [[ -n ${m_check[@]} ]]
		then
			m_PartsDisks+=("$i")
		fi
		unset m_check
	done
	echo "${m_PartsDisks[@]}"
}

EditDisk(){
	local disksArgs=$1[@]
	# local m_Disks=("${!disksArgs}")
	local m_Disks=(${!disksArgs})
	unset disksArgs

	# WritePartitionTable m_Disks

	local diskeditors=()

	for i in "gdisk" "cgdisk" "fdisk" "sfdisk" "cfdisk" "parted"
	do
		which "$i" &>/dev/null
		case $? in
			0) diskeditors+=("$i" "$i") ;;
			1) continue ;;
		esac
	done

	local disksTemp=("${m_Disks[@]}")
	disksTemp=($(TempArrayWithAmpersand disksTemp))
	# local DiskEditor="$(dialog --no-tags --cancel-label "Back" --menu "Disk Editor Menu\n\nSelect a Disk Editor to Edit the $disk ${disksTemp[*]}" 0 0 0 "${diskeditors[@]}" 3>&1 1>&2 2>&3)"
	local DiskEditor="$(dialog --no-tags --cancel-label "Back" --menu "Disk Editor Menu\n\nSelect a Disk Editor to Edit the $disk ${disksTemp[*]}" 0 0 0 "${diskeditors[@]}" 3>&1 1>&2 2>&3)"
	case $? in
		0)
			local m_NonePartDisks=()
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
	local PartTable="$(dialog --cancel-label "Back" --menu "Partition Table Menu\n\nSelect the partition Table to be written on $disk ${m_NoneDisksTemp[*]}" 0 0 0 "${PartTableTemp[@]}" 3>&1 1>&2 2>&3)"
	case $? in
		0)
			local m_DisksArgs=$1[@]
			local m_Disks=("${!m_DisksArgs}")
			unset m_DisksArgs

			local diskhave=($(TempArrayWithAmpersandHasHaveTexts ${#m_Disks[@]}))
			local m_DisksTemp=("${m_Disks[@]}")
			m_DisksTemp=($(TempArrayWithAmpersand m_DisksTemp))
			for b in ${m_Disks[@]}
			do
				parted "/dev/$b" mktable "$PartTable"
			done
			dialog --msgbox "$PartTable Partiton Table set on ${diskhave[0]} ${m_DisksTemp[*]}" 0 0 3>&1 1>&2 2>&3
			unset diskhave
			;;
		1)
			PartitionDisk
			;;
	esac
}

PartitionDisk(){

	local DiskList=($(DiskListTemp | awk '{print $1}'))
	declare -A DiskSize
	declare -A DiskPartTable
	declare -A DiskVendor
	declare -A DiskModelTemp
	declare -A DiskName

	local DiskListInfo=()

	for i in ${DiskList[@]}
	do
		DiskSize["$i"]="$(DiskListTemp "$i" | awk '{ print $2 }')"
		DiskPartTable["$i"]="$(DiskListTemp "$i" | awk '{ print $3 }')"
		DiskVendor["$i"]="$(DiskListTemp "$i" | awk '{ print $4 }')"
		DiskModelTemp["$i"]="$(DiskListTemp "$i" | awk '{ print $5 }')"
	done


	local DiskModelString=""
	for i in ${DiskList[@]}
	do
		DiskModelString="${DiskVendor[$i]} ${DiskModelTemp[$i]}"
		DiskName[$i]+="$DiskModelString"
		DiskModelString=""
	done

	for i in ${DiskList[@]}
	do
		if [[ -z ${DiskPartTable[$i]} ]] && [[ -z ${DiskSize[$i]} ]] && [[ -z ${DiskName[$i]} ]]
		then
            continue
        else
            DiskListInfo+=("$i")
			DiskListInfo+=("${DiskPartTable[$i]} | ${DiskSize[$i]} | ${DiskName[$i]}")
			DiskListInfo+=(0)
		fi
	done

	local Disks=()
	Disks=($(dialog --scrollbar --cancel-label "Back" --column-separator "|" --checklist "Disk Selection Menu" 0 0 0 "${DiskListInfo[@]}" 3>&1 1>&2 2>&3))
	DISKS_EXIT_CODE=$?

	if [[ ${#Disks[@]} -eq 1 ]]
	then
	    # local DiskPartsCheck=("$(DiskPartInfoTemp "${Disks[$a]}" | awk '{ print $1 }')")
	    local DiskPartsCheck=($(DiskPartInfoTemp "${Disks[$a]}" | awk '{ print $1 }'))
	    if [[ ${#DiskPartsCheck[@]} -eq 1 ]]
	    then
	    	local m_DisksTemp=("${Disks[@]}")
	    	m_DisksTemp=($(TempArrayWithAmpersand Disks))
	    	local diskshave=($(TempArrayWithAmpersandHasHaveTexts ${#Disks[@]}))
	    	dialog --yes-label "Back" --no-label "Edit" --yesno "A minimum of two partitions are required to install the linux system. 3 partitions if you plan on using swap. Edit the ${diskshave[0]} ${m_DisksTemp[*]} or go back to the Disks Selection Menu" 0 0
	    	case $? in
	    		0) PartitionDisk ;;
	    		1) EditDisk Disks ;;
	    	esac
	    fi
	fi

	case $DISKS_EXIT_CODE in
		1) MainMenu "Partition Disk **" ;;
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
						local m_DisksWithPartTableTemp=("${m_DisksWithPartTable[*]}")
						m_DisksWithPartTableTemp=($(TempArrayWithAmpersand m_DisksWithPartTable))
						local diskhave1100=($(TempArrayWithAmpersandHasHaveTexts ${#m_DisksWithPartTableTemp[@]}))

						local m_DisksTemp=("${Disks[@]}")
						m_DisksTemp=($(TempArrayWithAmpersand m_DisksTemp))
						local diskhave1111=($(TempArrayWithAmpersandHasHaveTexts ${#Disks[@]}))

						local m_NoPartTableDisksTemp=("${m_NoPartTableDisks[@]}")
						m_NoPartTableDisksTemp=($(TempArrayWithAmpersand m_NoPartTableDisksTemp))

						dialog --ok-label "Back" --cancel-label "Set Table" --extra-button --extra-label "Discard ${diskhave0000[0]}" --yesno "Selected ${diskhave0000[0]} ${m_NoPartTableDisksTemp[*]} does not contain a partition table. Set a Partition Table to the ${diskhave0000[0]}, Discard ${diskhave0000[0]} ${m_NoPartTableDisksTemp[*]} and use ${diskhave1100[0]} ${m_DisksWithPartTableTemp[*]} or go Back to the Disk Selection Menu" 0 0
						case $? in
							0)
								PartitionDisk
								unset m_NoPartTableDisks m_NoPartTableDisksTemp m_DisksTemp diskhave1111 diskhave0000 diskhave1100 m_DisksWithPartTable m_DisksWithPartTableTemp
								;;
							1)
								WritePartitionTable m_NoPartTableDisks
								EditDisk m_NoPartTableDisks
								unset m_NoPartTableDisks m_NoPartTableDisksTemp m_DisksTemp diskhave1111 diskhave0000 diskhave1100 m_DisksWithPartTable m_DisksWithPartTableTemp
								;;
							3)
								Disks=("$(DiscardFromArray Disks m_NoPartTableDisks)")
								dialog --msgbox "Discarded ${diskhave0000[0]} ${m_NoPartTableDisksTemp[*]}. Using ${diskhave1100[0]} ${m_DisksWithPartTableTemp[*]}" 0 0
								unset m_NoPartTableDisks m_NoPartTableDisksTemp m_DisksTemp diskhave1111 diskhave0000 diskhave1100 m_DisksWithPartTable m_DisksWithPartTableTemp
								;;
						esac
					fi
				fi


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
						DISKSWITHOUTPARTITIONSPRESENT_EXIT_CODE=$?
						case $DISKSWITHOUTPARTITIONSPRESENT_EXIT_CODE in
							0) CheckEditMount Disks $DISKSWITHOUTPARTITIONSPRESENT_EXIT_CODE ;;
							1) MountViewPartitions Disks ;;
						esac
						unset DISKSWITHOUTPARTITIONSPRESENT_EXIT_CODE
						# unset DISKSWITHOUTPARTITIONSPRESENT_EXIT_CODE Disks
						;;
					3)
						DisksWithoutPartitionsPresent Disks
						DISKSWITHOUTPARTITIONSPRESENT_EXIT_CODE=$?
						CheckEditMount Disks $DISKSWITHOUTPARTITIONSPRESENT_EXIT_CODE
						# CheckEditMount Disks $?
						# MountViewPartitions Disks
						;;
				esac
			fi
			;;
	esac
}

# View and mount all disks containing only linux install compatible partitions
MountViewPartitions(){

	# $1 - Disks

	local DisksArgs=$1[@]
	# local Disks=("${!DisksArgs}")
	local Disks=(${!DisksArgs})
	unset DisksArgs


	# local Disks=($(IFS="";sort <<<${Disks[@]}))

	local DisksTemp=("${Disks[@]}")
	local DisksTemp=($(TempArrayWithAmpersand DisksTemp))
	local NoPartDisks=("${Disks[@]}")
	local NoPartDisks=($(DisksWithoutPartitions NoPartDisks))


	local efi_parts
	local linux_fs_parts
	local linux_swap_parts
	local linux_home_parts
	local linux_user_home_parts

	# local DiskPartSizeTemp=()
	# local DiskPartFsTypeTemp=()
	# # local DiskPartFsFormatTemp=()
	# declare -A SelectedPartitions

	# local DiskPartName=()
	# local DiskPartListInfo=()
	local SelectedPartitions=()
	local DiscardDisks=()

	# declare -A DiskPartSize
	# declare -A DiskPartLabel
	# declare -A DiskPartFsType
	# declare -A DiskPartFsFormat

	if [[ -n "${NoPartDisks[@]}" ]]
	then
		local diskhave=($(TempArrayWithAmpersandHasHaveTexts ${#NoPartDisks}))
		local NoPartDisksTemp=("${NoPartDisks[@]}")
		NoPartDisksTemp=($(TempArrayWithAmpersand NoPartDisksTemp))
		dialog --yesno "${diskhave[0]} ${NoPartDisksTemp[*]} does not have any partitions. Edit the ${diskhave[0]}?" 0 0
		case $? in
			0) EditDisk NoPartDisks ;;
			1)
				Disks=($(DiscardFromArray Disks NoPartDisks))
				dialog --msgbox "Discarded ${diskhave[0]} ${NoPartDisksTemp[0]}. using ${diskhave[0]} ${Disks[*]}" 0 0
				;;
		esac
		unset NoPartDisksTemp diskhave NoPartDisks
	fi

	# for a in "${Disks[@]}"
	for (( a = 0; a < ${#Disks[@]}; a++))
	do
		local DiskPartName=($(DiskPartInfoTemp "${Disks[$i]}" | awk '{ print $1 }'))
		local DiskPartSizeTemp=($(DiskPartInfoTemp "${Disks[$i]}" | awk '{ print $2}'))
		local DiskPartFsTypeTemp=($(DiskPartTypeName "${Disks[$i]}" | awk '{ $1=$2=NULL; gsub("^\\s*",""); for(i=1;i<=NF;i++){ if(i == NF){ print $i" "i} else { print $i } } }'))

		declare -A DiskPartSize
		declare -A DiskPartLabel
		declare -A DiskPartFsType
		declare -A DiskPartFsFormat

		if [[ -z ${DiskPartSizeTemp[@]} ]] && [[ -z ${DiskPartFsTypeTemp[@]} ]] && [[ -z ${DiskPartName[@]} ]]
	    then
	        continue
	    elif [[ -n ${DiskPartSizeTemp[@]} ]] && [[ -n ${DiskPartFsTypeTemp[@]} ]] && [[ -n ${DiskPartName[@]} ]]
    	then
			DiskPartName=($(DiskPartInfoTemp "${Disks[$a]}" | awk '{ print $1 }'))
			# DiskPartSizeTemp=($(DiskPartInfoTemp "${Disks[$a]}" | awk '{ print $2 }'))
			# DiskPartLabelTemp=($(DiskPartInfoTemp "${Disks[$a]}" | awk '{ print $1=$2=NULL;gsub("^\\s+","");print $0 }'))

			#for partition size
			for i in ${DiskPartName[@]}
			do
				DiskPartSize["$i"]="$(lsblk /dev/"$i" -nlo size | sed 's/^\s*//g')"
			done

			#for partition label
			for i in ${DiskPartName[@]}
			do
				local m_label="$(lsblk /dev/"$i" -nlo partlabel | sed 's/^\s*//g')"
				if [[ -n "$m_label" ]]
				then
					DiskPartLabel["$i"]="$m_label"
				elif [[ -z "$m_label" ]]
				then
					DiskPartLabel["$i"]="(No Label)"
				fi
			done

			# for partition fstype name
			for i in ${DiskPartName[@]}
			do
				DiskPartFsType["$i"]="$(lsblk /dev/"$i" -nlo parttypename | sed 's/^\s*//g')"
			done


			# to form an array of partition for the checkbox
			local DiskPartListInfo=()
			for i in ${DiskPartName[@]}
			do
				local partinfo="${DiskPartSize[$i]} | ${DiskPartFsType[$i]} | ${DiskPartLabel[$i]}"
				DiskPartListInfo+=("$i")
				DiskPartListInfo+=("$partinfo")
				DiskPartListInfo+=(0)
				unset partinfo
			done
			unset DiskPartName DiskPartFsTypeTemp DiskPartSize DiskPartLabel DiskPartFsType

			local m_DiskVendor="$(lsblk "/dev/${Disks[$a]}" -dnlo vendor | sed 's/\s*$//g')"
			local m_DiskModel="$(lsblk "/dev/${Disks[$a]}" -dnlo model)"
			local m_DiskSize="$(lsblk "/dev/${Disks[$a]}" -dnlo size | sed 's/G/ GB/g;s/M/ MB/g;s/T/ TB/')"
			local m_DiskNameString="$m_DiskVendor $m_DiskModel"
			unset m_DiskVendor m_DiskModel

			local DisksSize=$((${#Disks[@]}-1))
			local partition=()
			partition=($(dialog --cancel-label "Back" --column-separator "|" --title "Partition Mount Menu" --extra-button --extra-label "Mount" --checklist "Partitions in /dev/${Disks[$a]} ($m_DiskNameString - $m_DiskSize) \n\ncheckbox items format:\nPartition--size--(filesystem type)--(partition label)" 0 0 0 "${DiskPartListInfo[@]}" 3>&1 1>&2 2>&3))
			PARTITION_EXIT_CODE=$?
			unset m_DiskSize m_DiskNameString
			for g in ${partition[@]}
			do
				local fstype="$(lsblk "/dev/$g" -nlo parttypename)"
				if [[ "$fstype" ==  "EFI System" || "$fstype" == "EFI (FAT-12/16/32)" ]]
				then
					efi_parts+=("$g")
				elif [[ "$fstype" ==  "Linux filesystem" || "$fstype" == "Linux" ]]
				then
					linux_fs_parts+=("$g")
				elif [[ "$fstype" ==  "Linux swap" ]]
				then
					linux_swap_parts+=("$g")
				elif [[ "$fstype" ==  "Linux home" ]]
				then
					linux_home_parts+=("$g")
				elif [[ "$fstype" ==  "Linux user's home" ]]
				then
					linux_user_home_parts+=("$g")
				fi
				unset fstype
			done

			# case $? in
			case $PARTITION_EXIT_CODE in
				0)
					# local SelectedPartitionsTemp+=("${partition[@]}")
					# if [[ -z "${SelectedPartitionsTemp[@]}" ]] && [[ -z "${partition[@]}" ]]
					if [[ -z "${partition[@]}" ]]
					then
						unset DisksSize
						# DiscardDisks=("${Disks[@]}")
						DiscardDisks=("${Disks[@]:$a}")
					# elif [[ -z "${SelectedPartitionsTemp[@]}" ]] && [[ -n "${partition[@]}" ]]
					elif [[ ! -z ${partition[@]} ]]
					then
						SelectedPartitions+=("${partition[@]}")
						# if  [[ $a -lt $DisksSize ]]
						if [[ "${Disks[-1]}" != "${Disks[$a]}" ]]
						then
							unset DisksSize
							a=$((a+1))
							DiscardDisks=("${Disks[@]:$a}")
							break
						fi
					fi

					if [[ ${#DiscardDisks[@]} -eq 1 ]] && [[ "${DiscardDisks[@]}" == "${Disks[@]}" ]]
					then
						dialog --msgbox "No Disk/Partiton selected for insallation. Please Select a Disk and few Partitions" 0 0
						unset DiscardDisks
						PartitionDisk
					elif [[ ${#DiscardDisks[@]} -eq 1 ]] && [[ "${DiscardDisks[@]}" != "${Disks[@]}" ]]
					then
						local diskhave=($(TempArrayWithAmpersandHasHaveTexts ${#DiscardDisks[@]}))
						local m_DiscardDisksTemp=(${DiscardDisks[@]})
						m_DiscardDisksTemp=($(TempArrayWithAmpersand m_DiscardDisksTemp))
						dialog --yes-label "OK" --no-label "Back" --yesno "Discarding ${diskhave[0]} ${m_DiscardDisksTemp[*]}" 0 0
						unset DiscardDisks m_DiscardDisksTemp diskhave
						break
					elif [[ ${#DiscardDisks[@]} -gt 1 ]] && [[ "${DiscardDisks[@]}" == "${Disks[@]}" ]]
					then
						unset DiscardDisks
						dialog --yes-label "Select Disk" --no-label "Select Partition" --yesno "No disk or partition selected for installation. Select Disks or Select Partitions from already Selected Disks?\n\nSelected Disks: ${Disks[*]}" 0 0
						case $? in
							0) PartitionDisk ;;
							1) MountViewPartitions Disks ;;
						esac
					elif [[ ${#DiscardDisks[@]} -gt 1 ]] && [[ "${DiscardDisks[@]}" != "${Disks}" ]]
					then
						local diskhave=($(TempArrayWithAmpersandHasHaveTexts ${#DiscardDisks[@]}))
						local m_DiscardDisksTemp=(${DiscardDisks[@]})
						m_DiscardDisksTemp=($(TempArrayWithAmpersand m_DiscardDisksTemp))
						dialog --yes-label "OK" --no-label "Back" --yesno "Discarding ${diskhave[0]} ${m_DiscardDisksTemp[*]}" 0 0
						unset DiscardDisks m_DiscardDisksTemp diskhave
						break
					fi
					;;
				1) PartitionDisk ;;

				3)
					if [[ -z "${partition[@]}" ]]
					then
						unset DisksSize
						DiscardDisks=("${Disks[$a]}")
					# elif [[ -z "${SelectedPartitionsTemp[@]}" ]] && [[ -n "${partition[@]}" ]]
					elif [[ -n ${partition[@]} ]]
					then
						# if  [[ $a -lt $DisksSize ]]
						if [[ "${Disks[-1]}" != "${Disks[$a]}" ]]
						then
							SelectedPartitions+=("${partition[@]}")
						elif [[ "${Disks[-1]}" == "${Disks[$a]}" ]]
						then
							SelectedPartitions+=("${partition[@]}")
							break
						fi
					fi
					DiskPartListInfo=()
					DiskPartFsType=()
					;;
			esac

		fi
		unset DiskPartSize DiskPartLabel DiskPartFsType DiskPartFsFormat DiskPartName DiskPartSizeTemp DiskPartFsTypeTemp
	done

	total_parts=$((${#linux_fs_parts[@]}+${#linux_swap_parts[@]}+${#linux_home_parts[@]}+${#linux_user_home_parts[@]}+${#efi_parts[@]}))

	local diskhave=($(TempArrayWithAmpersandHasHaveTexts ${#Disks[@]}))
	local m_DisksTemp=("${Disks[@]}")
	m_DisksTemp=($(TempArrayWithAmpersand m_DisksTemp))
	Disks=($(DiscardFromArray Disks DiscardDisks))
	unset DiscardDisks

	if [[ $total_parts -eq 0 ]]
	then
		local diskhave=($(TempArrayWithAmpersandHasHaveTexts ${#Disks[@]}))
		local m_DisksTemp=($(TempArrayWithAmpersand ${Disks[@]}))
		m_DisksTemp=($(TempArrayWithAmpersand m_DisksTemp))
		dialog --yes-label "Disk Menu" --no-label "Partition Menu" --yesno "No partitions selected for linux installation. Go Back to the Disk selection menu or select from selected ${diskhave[0]} ${m_DisksTemp[*]}" 0 0
		case $? in
			0)
				unset diskhave m_DisksTemp SelectedPartitions
				PartitionDisk
				;;
			1)
				unset diskhave m_DisksTemp SelectedPartitions
				MountViewPartitions Disks
				;;
		esac
	elif ([[ ${#linux_home_parts[@]} -eq 0 ]] || [[ ${#linux_user_home_parts[@]} -eq 0 ]]) && [[ ${#linux_swap_parts[@]} -ge 1 ]] && [[ ${#efi_parts[@]} -eq 1 ]] && [[ ${#linux_fs_parts[@]} -eq 1 ]] && [[ $total_parts -ge 3 ]]
	then
		dialog --yes-label "Back" --no-label "continue" --yesno "No linux home or linux user's home partition selected. Continue without one of these partitions or Go Back to the partition mount menu to select a home partition?" 0 0
		case $? in
			0)
				unset SelectedPartitions
				MountViewPartitions Disks
				;;
			1)
				ConfirmMounts Disks SelectedPartitions
				;;
		esac
	elif [[ ${#efi_parts[@]} -eq 1 ]] && [[ ${#linux_fs_parts[@]} -eq 1 ]] && ( [[ ${#linux_home_parts[@]} -eq 0 ]] || [[ ${#linux_user_home_parts[@]} -eq 0 ]] ) && [[ ${#linux_swap_parts[@]} -eq 0 ]]
	then
		dialog --yes-label "Back" --no-label "Continue" --yesno "No swap and linux home partitions selected. Continue without them or go back to the partition selection menu?" 0 0
		case $? in
			0)
				unset SelectedPartitions
				MountViewPartitions Disks
				;;
			1)
				ConfirmMounts Disks SelectedPartitions
				;;
		esac
	elif [[ ${#efi_parts[@]} -eq 1 ]] && [[ ${#linux_fs_parts[@]} -eq 1 ]] && [[ ${#linux_swap_parts[@]} -eq 0 ]]
	then
		dialog --yes-label "Back" --no-label "continue" --yesno "No swap partition selected. Recommended to have a swap partition. Continue without a swap partition or Go Back to the partition mount menu to select a swap partition?" 0 0
		case $? in
			0)
				unset SelectedPartitions
				MountViewPartitions Disks
				;;
			1)
				ConfirmMounts Disks SelectedPartitions
				;;
		esac
	elif [[ ${#efi_parts[@]} -gt 1 ]] && [[ ${#linux_fs_parts[@]} -gt 1 ]]
	then
		dialog --yes-label "Disk Menu" --no-label "Use Selected Disks" --yesno "Too many Linux essential partitions selected. Please select one linux filesystem and one EFI partition. The linux filesystem and one EFI partition are mandatory and the rest are optional though swap is a recommended optional. Go back to the Disk Selection Menu or Use the currently selected ${diskhave[0]} ${m_DisksTemp[*]}" 0 0
		case $? in
			0) 
				unset m_DisksTemp diskhave SelectedPartitions
				PartitionDisk
				;;
			1)
				unset m_DisksTemp diskhave SelectedPartitions
				MountViewPartitions Disks
				;;
		esac
	elif [[ ${#linux_fs_parts[@]} -eq 0 ]]
	then
		dialog --msgbox "No Disk with Linux filesystem selected. please select one from the partitions of the selected ${diskhave[0]} ${m_DisksTemp[*]}" 0 0
		unset diskhave m_DisksTemp SelectedPartitions
		MountViewPartitions Disks
	elif [[ ${#linux_fs_parts[@]} -gt 1 ]]
	then
		dialog --msgbox "Use one Linux filesystem partition. Using ${diskhave[0]} ${m_DisksTemp[*]}" 0 0
		unset diskhave m_DisksTemp SelectedPartitions
		MountViewPartitions Disks
	elif [[ ${#efi_parts[@]} -eq 0 ]]
	then
		dialog --msgbox "No EFI partition selected. Please Select one. (The EFI partition is basically where the kernel and the boot files reside)" 0 0
		unset SelectedPartitions
		MountViewPartitions Disks
	elif [[ ${#efi_parts[@]} -gt 1 ]]
	then
		dialog --msgbox "Use not more than one EFI partition (This is basically where the kernel and the boot files reside)" 0 0
		unset SelectedPartitions
		MountViewPartitions Disks
	fi
}

###################################################### end of disk editing #################################################




################################################## host configuration ######################################################

Install_UI(){
	# Install_UI
	# ConfHost
	# $1 - options in this function's menu

	pkgs=""
	wmopts=()
	ui_opts=()

	ui_opts+=("Window Manager")
	ui_opts+=("Just windows, statusbars, dmenus (minimal).No Graphics composition like on Gnome")
	ui_opts+=("Desktop Environment")
	ui_opts+=("Gnome, KDE, cinnamon and stuff like that")

	local UI
	UI=$(dialog --cancel-label "BACK" --default-item "${1}" --menu "UI Menu" 0 0 0 "${ui_opts[@]}" 3>&1 1>&2 2>&3)
	case $? in
		1) ConfHost "Install UI" ;;
		0)
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
					local DE
					DE=$(dialog --cancel-label "BACK" --menu "Desktop Environment Menu" 0 0 0 "${deopts[@]}" 3>&1 1>&2 2>&3)
					case $? in
						1) Install_UI "Desktop Environment" ;;
						0) 
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
					esac
					;;
				"Window Manager")
					local WM
					WM=$(dialog --cancel-label "BACK" --menu "Window Manager Menu" 0 0 0 "${wmopts[@]}"  3>&1 1>&2 2>&3)

					case $? in
						1) Install_UI "Window Manager" ;;
						0)
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
									dialog --msgbox "no window managers available" 0 0
							esac
							;;
					esac
					;;
				*)
					dialog --menu "SIKE" 0 0
					;;
			esac
			dialog --msgbox "$pkgs" 0 0
			pacstrap /mnt $pkgs | GuageMeter "Installing packages $pkgs" 1
			# pacstrap /mnt $pkgs
			ConfHost "Install UI"
			;;
	esac

}

SetTz(){
	# $1 - default option
	local regions=()
	local regions_dir_temp=($(ls -d /usr/share/zoneinfo/* | grep -iv 'right\|posix\|\.[a-zA-Z0-9]*'))
	local regions_temp=($(ls /usr/share/zoneinfo/ | grep -iv 'right\|posix\|\.[a-zA-Z0-9]*'))

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
	unset a

	# unset regions_temp regions_dir_temp
	local region
	region=$(dialog --cancel-label "Back" --no-tags --menu "select the continent you are in" 0 0 0 "${regions[@]}" 3>&1 1>&2 2>&3)
	case $? in
		1) ConfHost "set timezone" ;;
		0)
			local zones=()
			local zones_temp=()
			local zones_temp_dir=()
			zones_temp=($(ls "/usr/share/zoneinfo/$region"))
			zones_temp_dir=($(ls -d "/usr/share/zoneinfo/$region/*"))
			# zones_temp=($(ls $region))
			# zones_temp_dir=($(ls -d $region/*))

			local a=0
			for b in "${zones_temp_dir[@]}"
			do
				if [[ -f "$b" ]] && [[ -r "$b" ]]
				then
					zones+=($b)
					zones+=(${zones_temp[$a]})
				fi
				((a+=1))
			done
			unset a

			local zone
			zone=$(dialog --cancel-label "back" --no-tags --menu "select the region you are in" 0 0 0 "${zones[@]}" 3>&1 1>&2 2>&3)
			case $? in
				1) SetTz ;;
				0)
					ln -sf $zone /mnt/etc/localtime &>/dev/null
					# arch-chroot /mnt/ hwclock -wrv | dialog --programbox "hardwareClock Set" 0 0
					arch-chroot /mnt/ hwclock -wrv | GuageMeter "Setting Hardware Clock" 1
					if [[ ${PIPESTATUS[0]} -eq 0 ]]
					then
						dialog --msgbox "Hardware Clock and timezone are set $zone" 0 0
					elif [[ ${PIPESTATUS[0]} -eq 0 ]]
					then
						dialog --msgbox "timezone or Hardware Clock could not be set" 0 0
					fi
					;;
			esac
			;;
	esac
}

SetLocale(){

	# user set locale

	LOCALE=()
	# cat "locale.gen" | grep -i '#[a-zA-Z0-9]' | sed 's/#//' > locales.txt
	cat "/etc/locale.gen" | grep -i '#[a-zA-Z0-9]' | sed 's/#//' > locales.txt

	# dialog --msgbox "when you press a character and you don't see the character, just keep that charcter held until you see the cursor" 0 0

	while read txt
	do
		LOCALE+=("$txt")
		LOCALE+=("$txt")
		LOCALE+=(OFF)
	done < locales.txt

	# back - 1
	# ok - 0
	local LocaleDialog
	LocaleDialog=$(dialog --scrollbar --visit-items --cancel-label "BACK" --title "Locale Selection Menu" --buildlist "\nUse the space bar to move locale options between the panes and use the tab for moving in between spacess. If no locale is selected then the deafult UTF-8 and ISO-8859 versions of the US english locales will be set \n\n           disabled locales                                          enabled locales" 0 0 0 "${LOCALE[@]}" 3>&1 1>&2 2>&3)
	echo "${LocaleDialog[@]}" | sed 's/" "/"\n"/g;s/"//g' > locales.txt
	while read txt
	do
		sed -i s/"#$txt"/"$txt"/g /mnt/etc/locale.gen
		# awk '{print ARGV}'
	done < locales.txt
	rm -rfv locales.txt &>/dev/null
	local LocaleFormat
	LocaleFormat=$(echo -e "\n\n${LocaleDialog[*]}\n" | sed 's/" "/"\n"/g')
	# locale-gen | GuageMeter "Generating Locales" 1
	dialog --msgbox "locales set:$LocaleFormat" 0 0
}

SetHostName(){
	local hostname="$(dialog --inputbox "Set host name" 0 0 3>&1 1>&2 2>&3)"
	if [[ -z $hostname ]]
	then
		dialog --yesno "Default name 'arch' will be assigned as hostname. continue?" 0 0
		case $? in
			0) hostname="arch" ;;
			1) SetHostName ;;
		esac
	fi
	echo "$hostname" > "/mnt/etc/hostname"
	dialog --msgbox "set $hostname as hostname. You can change the hostname in the /etc/hostname file (if you are not in live mode i.e.) or if you are in live mode then edit the /mnt/etc/hostname file" 0 0
	arch-chroot /mnt echo -e "127.0.0.1\tlocalhost\n      ::1\tlocalhost" > "/mnt/etc/hostname"
}

SetPassword(){
	local username=$1
	# local password=$2
	local NewPassword="$(dialog --passwordbox "set password for username $username" 0 0 3>&1 1>&2 2>&3)"
	case $? in
		1)
			# ConfHost "add users"
			add_users
			;;
		0)
			# if [[ ${#NewPassword} -eq 0 ]]
			if [[ -z $NewPassword ]]
			then
				dialog --yesno "Accounts without passwords is as good as an inaccessible account (i.e. if the passwordless account is the only non-root account you have created). linux will prompt you for a password regardless of password state on an account/username.\nYou can login into the passwordless account by doing one, select few or all of the following\n1) logging in with an account that contains a password (if you have created one i.e.) and then logging in with the 'passwordless account' from the currently active account\n2) logging in as root and then loggin in with the 'passwordless account'.\n3) going to line 79 of /etc/sudoers and adding '<passwordless account name> ALL=(ALL) NOPASSWD: ALL'\n\nAll the above is as per my experience.\nProceed setting the passwordless account regardless?" 0 0
				case $? in
					0) password="$NewPassword" ;;
					1) SetPassword $username ;;
					# 1) SetPassword $username $password ;;
				esac
			else
				if [[ ${#NewPassword} -lt 8 ]] && [[ ${#NewPassword} -gt 0 ]]
				then
					dialog --msgbox "password need to be atleast 8 characters long" 0 0
					SetPassword $username
					# SetPassword $username $password
				elif [[ ${#NewPassword} -ge 8 ]]
				then
					local ConfirmPassword="$(dialog --passwordbox "Confirm password for username $username" 0 0 3>&1 1>&2 2>&3)"
					if [[ $ConfirmPassword == $NewPassword ]]
					then
						password=$NewPassword
					elif [[ "$ConfirmPassword" != "$NewPassword" ]]
					then
						dialog --msgbox "passwords do not match" 0 0
						SetPassword $username
						# SetPassword $username $password
					fi
				fi
			fi
			;;
	esac
}

add_users(){
	# local password=""
	local username="$(dialog --inputbox "Username" 0 0 3>&1 1>&2 2>&3)"
	case $? in
		1) ConfHost "add users **" ;;
		0)
			if [[ -z $username ]]
			then
				dialog --msgbox "username cannot be an empty string" 0 0
				add_users
			elif [[ -n $username ]]
			then
				dialog --msgbox "you won't see the password characters as they are typed" 0 0
				SetPassword $username
				# SetPassword $username $password
			fi
			dialog --msgbox "created username $username and password is set" 0 0
			arch-chroot /mnt useradd -m $username -G users -g power,wheel,storage &>/dev/null
			case $? in
				0) 
					dialog --msgbox "Created user $username" 0 0
					SetPassword $username
					arch-chroot /mnt passwd $username &>/dev/null
					;;
				9)
					dialog --yesno "User $username already exists. Reset password?" 0 0
					case $? in
						0)
							SetPassword $username
							arch-chroot /mnt passwd $username &>/dev/null
							;;
					esac
					;;
			esac
			
			;;
	esac
}

BashPromptPreview(){
	clear
	bash_prompt="$1"
	curdir="$PWD"
	bash --rcfile "$curdir/shell rc/bash/$bash_prompt"
}

SetPrompt(){

	bashrc_file="$1"

	local Users=($(grep [1-9][0-9][0-9][0-9] /mnt/etc/passwd | grep -iv nobody | sed 's/\:/ \: /g' | awk '{print $1}'))
	if [[ ${#Users[@]} -eq 1 ]]
	then
		cp -rfv bashrc/"$1" /mnt/home/$Users/.bashrc &>/dev/null
		# cp -rf bashrc/"$1" /home/$Users/.bashrc &>/dev/null
		dialog --msgbox "set $1 as the bash prompt for user ${Users[0]}" 0 0
	elif [[ ${#Users[@]} -gt 1 ]]
	then
		dialog --extra-button --extra-label "Few" --ok-label "One" --no-label "All" --yesno "set  for all users, one user or selected user?" 0 0
		case $? in
			0)
				local UsersTemp=()
				for i in ${Users[@]}
				do
					UsersTemp+=("$i" "")
				done
				local User="$(dialog --no-tags --menu "Select a user to set the $bashrc_file bashrc file" 0 0 0 "${UsersTemp[@]}" 3>&1 1>&2 2>&3)"

				cp -rfv bashrc/"$bashrc_file" /mnt/home/$User/.bashrc &>/dev/null
				dialog --msgbox "Set $bashrc_file for user $User" 0 0
				unset Users UsersTemp
				;;
			1)
				for i in ${Users[@]}
				do
					# cp -rfv bashrc/"$bashrc_file" /mnt/home/$i/.bashrc &>/dev/null
					echo "\"cp -rfv bashrc/\$bashrc_file\" \"/mnt/home/\$i/.bashrc &>/dev/null\""
				done
				dialog --msgbox "Set $bashrc_file for all users" 0 0
				;;
			3)
				local UsersTemp=()
				for i in ${Users[@]}
				do
					UsersTemp+=("$i" "" 0)
				done

				local SelectedUsers="$(dialog --no-tags --checklist "Select users that will use this $bashrc_file bashrc file" 0 0 0 "${UsersTemp[@]}" 3>&1 1>&2 2>&3)"

				local userText=""
				if [[ ${#SelectedUsers[@]} -eq 1 ]]
				then
					userText="user"
				elif [[ ${#SelectedUsers[@]} -gt 1 ]] && [[ ${#SelectedUsers[@]} -lt ${#Users[@]} ]]
				then
					userText="users"
				elif [[ ${#SelectedUsers[@]} -eq ${#Users[@]} ]]
				then
					userText="all"
				fi

				local SelectedUsersTemp=($(TempArrayWithAmpersand SelectedUsers))

				for i in ${SelectedUsers[@]}
				do
					cp -rf bashrc/"$bashrc_file" /mnt/home/$User/.bashrc &>/dev/null
					# echo "\"cp -rf bashrc/\$bashrc_file\" \"/mnt/home/\$User/.bashrc &>/dev/null\""
				done | GuageMeter "Setting $bashrc_file for $userText ${SelectedUsersTemp[@]}"
				# done

				dialog --msgbox "Set $bashrc_file for $userText ${SelectedUsersTemp[@]}" 0 0
				unset SelectedUsers SelectedUsersTemp UsersTemp userText
				;;
		esac
	fi
	unset Users
}

SetBashPrompt(){
	# $1 - "menu option item"

	local bashrc_opts=("default" "it's the same as you see on the live iso")
	bashrc_opts+=("modded parrot" "my personalized version of the parrot OS bash prompt")
	bashrc_opts+=("parrot" "bash prompt taken from parrot OS")
	bashrc_opts+=("pop OS" "pop OS bash prompt")
	local Users=($(grep [1-9][0-9][0-9][0-9] /etc/passwd | grep -iv nobody | sed 's/\:/ \: /g' | awk '{print $1}'))

	$1="${bashrc_opts[0]}"

	# exit code references
	# 0 - set bashrc
	# 3 - preview
	# 1 - back
	local bashrc
	bashrc=$(dialog --ok-label "set bashrc" --default-item "$1" --extra-button --extra-label "preview" --cancel-label "back" --menu "bashrc selection menu\n\nselected menuitem will be saved as \".bashrc\" in the home directory" 0 0 0 "${bashrc_opts[@]}" 3>&1 1>&2 2>&3)

	case $? in
		0)
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
			;;
		1) ConfHost "Set Bash Prompt" ;;
		3)
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
			;;
	esac
}

SetRootPassword(){
	local RootPassword
	RootPassword=$(dialog --no-cancel --passwordbox "Enter root password. If no root password is provided then root password will be set to 'try again'. if default password is set please change the default root password post installation as it can be cracked through rainbow tables, dictionary or brute force attacks" 0 0 3>&1 1>&2 2>&3)
	if [[ -z $RootPassword ]]
	then
		RootPassword="try again"
		arch-chroot "echo $RootPassword;echo $RootPassword" | passwd &>/dev/null
		dialog --msgbox "default root password 'try again' is set " 0 0
	elif [[ -n $RootPassword ]]
	then
		local ConirmRootPassword
		ConirmRootPassword=$(dialog --passwordbox "confirm root password" 0 0 3>&1 1>&2 2>&3)
		if [[ "$RootPassword" != "$ConfirmPassword" ]]
		then
			dialog --msgbox "root password does not match" 0 0
			SetRootPassword
		elif [[ "$RootPassword" == "$ConfirmPassword" ]]
		then
			arch-chroot "echo $RootPassword;echo $RootPassword" | passwd &>/dev/null
			dialog --msgbox "root password is set" 0 0
		fi
	fi
}

ConfHost(){
	# $1 - menu option item

	mountpoint /mnt &>/dev/null
	case $? in
		0)
			local HostOpt=("set hostname *" "set your computer name")
			HostOpt+=("set Locale *" "set your computer language")
			HostOpt+=("set timezone" "configure which timezone you are in")
			HostOpt+=("add users **" "add users")
			HostOpt+=("root password *" "set root password")
			HostOpt+=("Install UI" "Install Desktop Environment or Window Manager")
			HostOpt+=("Set Bash Prompt" "File that's used to tell how the terminal prompt should look like")
			# local "${HostOpt[0]}"=$1
			$1="${HostOpt[0]}"
			local opt
			opt=$(dialog --cancel-label "BACK" --default-item "${1}" --menu "Host Configuration Menu" 0 0 0 "${HostOpt[@]}" 3>&1 1>&2 2>&3)
			case $? in
				0)
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
					;;
				1) MainMenu "Configure Host +" ;;
			esac
			;;
		1) 
			dialog --msgbox "cannot configure host without a linux root partition" 0 0
			MainMenu "Configure Host +"
			;;
	esac
}
############################################## end of host configuration ###################################################


InstallArch(){

	if ! mountpoint /mnt &>/dev/null
	then
		dialog --msgbox "root partition not mounted" 0 0
		MainMenu "Install Arch *"
	elif mountpoint /mnt &>/dev/null
	then
		# nvidia linux nvlink/capabilities/fabric-mgmt 0
		local packages=()
		packages_temp=(base base-devel devel linu{x,x-{docs,headers}} grub efi{var,bootmgr} dkms broadcom-dkms-wl-dkms xf86-input-{libinput,synaptics} xf86-video-fbdev)
		for i in "${packages_temp[@]}"
		do
			packages+=("$i")
		done
		unset packages_temp

		# pacstrap /mnt "${packages[@]}"
		# case $? in
		pacstrap /mnt "${packages[@]}" | GuageMeter "Installing Arch Base system packages" 1
		case ${PIPESTATUS[0]} in
			0)
				local bootloaderid="$(dialog --inputbox "Bootloader ID - Input Any Text" 0 0 3>&1 1>&2 2>&3)"
				grub-install -v --boot-directory="/mnt/boot" --bootloader-id "$bootloaderid" --efi-directory="/mnt/boot" --recheck --removable --target x86_efi-efi
				echo "grub-install -v --boot-directory=\"/mnt/boot\" --bootloader-id \"$bootloaderid\" --efi-directory=\"/mnt/boot\" --recheck --removable --target x86_efi-efi"
				case $? in
					0) dialog --msgbox "Grub successfully installed" 0 0;MainMenu "Install Arch *" ;;
					1) dialog --msgbox "could not install grub-bootloader. you execute \'grub-install --help | less\' on one tty and run \'grub-install <options>\' on another tty. \n\nDO NOT USE THE \'--force\' option.You can open tty's by pressing ctrl+alt+<F1>-<F6> with each function key corresponding to their tty id\n\n Go back to the Main Menu or exit to the tty?" ;;
				esac
				dialog --msgbox "Installed Arch Base system" 0 0
				;;
			*)
				dialog --msgbox "Failed to install Arch Base system. Exiting the Installer" 0 0
				exit
				;;
		esac
		packages=()

		cpu_vendor=$(cat /proc/cpuinfo | grep vendor | uniq | awk '{print $3}')

		local intel_gpu=()
		local intel_gpu_temp=(libva-intel-driver lib32-{libva-intel-driver,vulkan-intel} vulkan-intel intel-graphics-compiler)
		for i in ${packages_temp[@]}
		do
			intel_gpu+=("$i")
		done
		unset intel_gpu_temp


		local nvidia_gpu=()
		local nvidia_gpu_temp=(ffnvcodec-headers libvdpau opencl-nvidia xf86-video-nouveau lib32-{libvdpau,nvidia-utils,opencl-nvidia} nvidia-{dkms,lts,prime,settings,utils})
		for i in ${packages_temp[@]}
		do
			nvidia_gpu+=("$i")
		done
		unset nvidia_gpu_temp



		if [[ $cpu_vendor == "AuthenticAMD" ]]
		then
			packages=("amd-ucode")
			packages+=("amdvlk")
			packages+=("lib32-amdvlk")
			packages+=("opencl-mesa")
			packages+=("lib32-opencl-mesa")
			packages+=("xf86-video-amdgpu")
		elif [[ $cpu_vendor == "GenuineIntel" ]]
		then
			packages=("intel-ucode")
			packages+=("tbb")
			packages+=("intel-undervolt")
			packages+=("throttled")
			packages+=("xf86-video-intel")
			packages+=("${intel_gpu[@]}")
		fi

		local terminaleditorslist=()
		terminaleditorslist=("vim" "vim" off)
		terminaleditorslist+=("neovim" "neovim" off)
		terminaleditorslist+=("emacs" "emacs" off)
		terminaleditorslist+=("joe" "joe" off)
		terminaleditorslist+=("nedit" "nedit" off)
		terminaleditorslist+=("kakoune" "kakoune" off)
		terminaleditorslist+=("zile" "zile" off)
		terminaleditorslist+=("mg" "mg micro emacs" off)

		local editors=()
		editors=($(dialog --extra-button --extra-label "Cancel" --cancel-label "Back" --no-tags --title "text editor selection Menu" --checklist "nano and vi will be installed by default" 0 0 0 "${terminaleditorslist[@]}" 3>&1 1>&2 2>&3))
		case $? in
			0)
				unset terminaleditorslist
				if [[ -n "${editors[@]}" ]]
				then
					packages="${packages[@]} ${editors[@]}"
				elif [[ -z "${editors[@]}" ]]
				then
					# packages="${packages[@]}"
					:
				fi
				;;
			1)
				unset terminaleditorslist
				MainMenu "Install Arch *"
				;;
			3)
				:
				unset terminaleditorslist
				# packages="${packages[@]}"
				break
				;;
		esac

		dialog --msgbox "Extra packages that will be installed:\n${packages[*]}" 0 0

		# pacstrap /mnt "$packages"
		# case $? in
		pacstrap /mnt "$packages" | GuageMeter "Installing extra linux packages" 1
		case ${PIPESTATUS[0]} in
			0) dialog --msgbox "Extra Linux packages have been installed packages" 0 0;;
			*) dialog --msgbox "failed to install Extra Linux packages" 0 0;;
		esac
	fi
}

Repo_Enable(){
	dialog --yesno "enable \"multilib\" repo for packages with support for multiple architectures?" 5 80
	case $? in
		0)
			sed '94s/\#\[/"["' /etc/pacman.conf
			sed '95s/\#\[/""' /etc/pacman.conf
			dialog --msgbox "\"multilib\" repo has been enabled. you can add, remove, disable or enable repos by editing the \"/etc/pacman.conf\" file" 0 0
			;;
		1)
			dialog --no-label "exit" --yes-label "continue installation" --yesno "multilib repo not enabled. To enable it restart the script or uncomment lines 94 and 95 in file \"/etc/pacman.conf\"" 6 63
			case $? in
				0) exit ;;
				1) echo "" ;;
			esac
	esac
}

MainMenu(){

	# $1 - menu option item

	clear
    # check if dialog is installed
	# pacman -Qs dialog &>/dev/null
	ls /usr/bin/dialog &>/dev/null
	case $? in
		# 0)
		# 	echo ""
		# 	;;
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
					# echo -e "\n\ndialog could not be installed"
					echo -e "\n\ndialog could not be installed.\n\nPlease install provided dialog packages by typing \"pacman -Uvd <package name>\" with or without the \"--noconfirm\" argument.\n\ncurrent directory:\n$(pwd)\n\npackages in this directory:\n$(ls *.pkg*).\n\n\nexiting...\n\n"
					exit
					;;
			esac
			;;
	esac


	local menuopt=("Partition Disk **" "format/Partition/select Hard Disks and mount partitions")
	menuopt+=("Configure Network **" "Check connectivity and connect to a network")
	menuopt+=("Install Arch *" "Install the base system")
	menuopt+=("Configure Host +" "Personalize the machine by setting Hostname, adding users etc.")
	menuopt+=("Reboot" "Reboot the computer")

	local menuitem
	menuitem=$(dialog --no-mouse --default-item "${1}" --cancel-label "Exit" --title "Install Menu" --menu "To install arch all options followed by\n  i) '**' are priority 1\n ii) '*'are priority 2\niii) '+'are priority 3\n\nThe rest are optional" 0 0 0 "${menuopt[@]}" 3>&1 1>&2 2>&3)

	case $? in
		0)
			case $menuitem in
				"Partition Disk **")
					PartitionDisk
					MainMenu "Partition Disk **"
					;;
				"Configure Network **")
					# dialog --msgbox "Configure Network" 0 0
					ConfNet
					# if [[ $? -eq 1 ]]
					# then
					# 	MainMenu "Configure Network **"
					# fi
					MainMenu "Configure Network **"
					;;

				"Install Arch *")
						InstallArch
					;;


				"Configure Host +")
					# arch-chroot /mnt
					mountpoint /mnt
					case $? in
						1)
							dialog --msgbox "no root partition set" 0 0
							;;
						*)
							ConfHost "set hostname *"
							;;
					esac

					MainMenu "Configure Host +"
					;;

				"Reboot")
					dialog --yesno "Reboot the machine" 0 0
					case $? in
						0)
							dialog --yesno "save basic customization instructions in the arch partition? It will be stored in the /home/customize.txt file of your arch install location. use less, more, cat or a text editor like vim, vi, emacs or nano to view the file" 0 0
							case $? in
								1)
									dialog --msgbox "saved basic customization instructions in /mnt/home/customize.txt" 0 0
									echo -e "change hostname - vim /etc/hostname\ncreate users - useradd -m\n<username> -G power,storage,wheel -g users\nset or change user password - passwd <username>\nset or change user password - passwd\nset locale - vim /etc/locale.gen, comment '#' to ignore and uncomment to generate or use the locale\n\n(DE - Desktop Environment, WM - Window Manager) to install a DE - install a minimal DE package or the group using the '-g' argument in pacman and a lockscreen manager. enable the lockscreen manager using the systemctl tool and write the DE session name in the /home/<user name>/.xinitrc file\n to install a WM - install a WM and the lockscreen manager will pick it up (if enabled)\nset timezone - soft link (ln -sf) /usr/share/zoneinfo/<continent>/<region> /etc/localtime execute hwclock -w -v (-v is optional if you prefer verbosity (basically more details of what's going on ))" > /mnt/home/customize.txt
									;;
							esac
							;;
						1) MainMenu "Reboot" ;;
					esac

					reboot now -f
					# clear;reset
					;;
				*)
					dialog --msgbox "sike" 0 0
					MainMenu "Reboot"
					;;
			esac
			;;
		1) clear;reset;exit ;;
	esac

}

# trap '' 2
# Repo_Enable
MainMenu "Partition Disk **" 3>&1 1>&2 2>&3
