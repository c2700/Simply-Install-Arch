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

# DIALOG_CANCEL=0
# DIALOG_OK=1
# DIALOG_HELP=2
# DIALOG_HELP_ITEM_HELP=2
# DIALOG_EXTRA=3
# DIALOG_ESC=255



# commonly used code blocks

# pretty much like a progress bar
GuageMeter(){
	# $1 - guagebox text
	# $2 - number
 	c=0
	while [ $c -le 100 ]
	    do
	        echo "###"
			echo "$c"
			echo "### $c%"
			((c+=$2))
	        ((c+=1))
	done | dialog --gauge "${1}" 0 0 0
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

# return has/have and disk/disks texts based on the number of elements in the array passed as argument
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

# return an array with an "&" in the -2 index of an array passed as argument
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

	# pass in network arguments
	clear
	iwctl station "$wireless_dev" scan
	clear
	iwctl station "$wireless_dev" get-networks | more && read -p "Enter Wireless network to connect to : " SSID
	dialog --yesno "view wireless passphrase in plaintext as you enter?" 0 0
	case $? in
		0)
			printf "$SSID password: "
			read pass
			iwctl --passphrase $pass station $wireless_dev connect $SSID
			iw_reconnect $? $wireless_dev $SSID "$(read -p "$SSID password: ")"
			;;
		1)
			iwctl station $wireless_dev connect $SSID
			iw_reconnect $? $wireless_dev $SSID
			;;
	esac
}


ConfNet(){

	# check network availability
	ping -c4 google.com &>/dev/null | GuageMeter "Checking for network availablity" 1
	if [[ ${PIPESTATUS[0]} -eq 0 ]]
	then
		dialog --title "Installed Network Manager" --msgbox "network available" 0 0
		MainMenu "Configure Network **"
	else
		dialog --title "Network Status" --msgbox "network not available. will search for available network managers" 0 0
	fi

	# create an array of available network managers for use in dialog
	local NMList=()
	ls /bin/wifi-menu &>/dev/null
	case $? in
		0)
			NMList+=("wifi-menu")
			NMList+=("")
			;;
	esac
	
	ls /usr/lib/systemd/system/NetworkManager* &>/dev/null
	case $? in
		0)
			NMList+=("networkmanager")
			NMList+=("")
			;;
	esac

	ls /usr/lib/systemd/system/iwd* &>/dev/null
	case $? in
		0)
			NMList+=("iwd")
			NMList+=("")
			;;
	esac	

	if [[ -z ${NMList[@]} ]]
	then
		unset NMList
		dialog --msgbox "no networkmanagers available. Local networkmanager package will be installed" 0 0
		pacman -Uvd --noconfirm --needed "$(ls networkmanager*)"
		dialog --msgbox "enabling NetworkManager" 0 0
		nmtui
		MainMenu "Configure Network"
	elif [[ -n ${NMList[@]} ]]
	then
		local NM
		NM=$(dialog --cancel-label "BACK" --menu "Availble Network Managers" 0 0 0  "${NMList[@]}" 3>&1 1>&2 2>&3)

		case $? in
			0)
				case $NM in
					"wifi-menu")
						unset NMList
						wifi-menu
						;;
					"networkmanager")
						unset NMList
						nmtui
						MainMenu "Configure Network **"
						;;
					"iwd")
						unset NMList
						iwd_mngr
						MainMenu "Configure Network **"
						;;
				esac
				;;
			1)
				unset NMList
				MainMenu "Configure Network **"
				;;
		esac
	fi
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

	local linuxfs="ext4"

	# filesystem selection menu
	dialog --yes-label "Change filesystem" --no-label "Use Default" --yesno "Use default ext4 for linux filesystem or use a different filesystem?" 0 0
	case $? in
		0)
			local linuxfs_list=()
			linuxfs_list+=("ext4" "ext4")
			linuxfs_list+=("ext3" "ext3")
			linuxfs_list+=("ext2" "ext2")
			linuxfs_list+=("btrfs" "btrfs")
			linuxfs_list+=("bfs" "bfs")
			linuxfs_list+=("xfs" "xfs")
			linuxfs_list+=("zfs" "zfs")
			linuxfs_list+=("jfs" "jfs")
			local linuxfschange=""
			linuxfschange=$(dialog --no-tags --menu "Select filesystem to use as linux filesystem" 0 0 0 "${linuxfs_list[@]}" 3>&1 1>&2 2>&3)
			case $? in
				0)
					if [[ "$linuxfs" == "$linuxfschange" ]]
					then
						dialog --msgbox "default linux filesystem ext4 has not been changed" 0 0
					elif [[ "$linuxfs" != "$linuxfschange" ]]
					then
						linuxfs="$linuxfschange"
						dialog --msgbox "Using $linuxfs filesystem" 0 0
					fi
					;;
				1) dialog --msgbox "Using default ext4 linux filesystem" 0 0 ;;
			esac
			;;
		1) dialog --msgbox "Using default ext4 linux filesystem" 0 0 ;;
	esac
	unset linuxfs_list

	# arrays that will store disks that will be mounted or is mounted, will be formatted or reformatted using existing, selected (root and home partitions only) or default filesystem
	local Reformat_Disks=()
	local Format_Disks=()
	local MountParts=()
	local m_MountedPartitions=()

	for k in ${m_MountDisksTemp[@]}
	do
		local m_DiskName=$(lsblk /dev/$k -dnlo vendor,model | awk '{ gsub("\\s+"," "); print $0 }') # gets disk name in one text
		local m_DiskSize=$(lsblk /dev/$k -dnlo size | sed 's/^\s*//g;s/[mM]/ MB/g;s/[gG]/ GB/g;s/[tT]/ TB/g') # changes "M" to " MB"
		local m_DiskPartTable=$(lsblk /dev/$k -dnlo pttype)
		local MountPartsString="\n/dev/$k ($m_DiskName - $m_DiskPartTable - $m_DiskSize)\n" # array of disk info string
		unset m_DiskName m_DiskSize

		# make an array of selected partitions to their respective disks
		local m_partitions=()
		for m in ${m_MountPartitionsTextsTemp[@]}
		do
			if [[ "$m" =~ "$k" ]]
			then
				m_partitions+=("$m")
			fi
		done

		# create array of disk and partition info strings to view as a tree structure in the mount confirmation dialog when partitions are equal to one
		if [[ ${#m_partitions[@]} -eq 1 ]]
		then
			local partfsformat=$(lsblk /dev/${m_partitions[0]} -nlo fsver,fstype | sed 's/FAT32 vfat/FAT32/g;s/1.0   ext4/ext4/g;s/1     swap/swap/g')
			local partsize=$(lsblk /dev/${m_partitions[0]} -nlo size | sed 's/^\s*//g;s/[mM]/ MB/g;s/[gG]/ GB/g;s/[tT]/ TB/g')
			local m_partlabel=$(lsblk /dev/${m_partitions[0]} -nlo partlabel)
			local m_parttypename=$(lsblk /dev/${m_partitions[0]} -nlo parttypename)
			local m_MountPoint=$(lsblk /dev/${m_partitions[0]} -nlo mountpoint)

			if [[ -n $m_partlabel ]]
			then
				MountPartsString+="  \`-/dev/${m_partitions[0]} --> $partsize --> $m_partlabel --> $m_parttypename"
			elif [[ -z $m_partlabel ]]
			then
				MountPartsString+="  \`-/dev/${m_partitions[0]} --> $partsize --> (No Label) --> $m_parttypename"
			fi

			if [[ -n $partfsformat ]] || [[ "$partfsformat" != "" ]] || [[ ! "$partfsformat" =~ " " ]]
			then
				if [[ "$m_parttypename" == "EFI System" ]] || [[ "$m_parttypename" == "EFI (FAT-12/16/32)" ]]
				then
					if [[ -z $m_MountPoint ]]
					then
						MountPartsString+=" --> *$partfsformat --> /mnt/boot\n"
					elif [[ -n $m_MountPoint ]] || [[ "$m_MountPoint" != "" ]] || [[ ! "$m_MountPoint" =~ " " ]]
					then
						MountPartsString+=" --> *$partfsformat --> $m_MountPoint (mounted)\n"
						m_MountedPartitions+=("${m_partitions[0]}")
					fi
					Reformat_Disks+=("${m_partitions[0]}")
				elif [[ "$m_parttypename" == "Linux swap" ]]
				then
					if [[ -z $m_MountPoint ]]
					then
						MountPartsString+=" --> *$partfsformat --> (use as swap)\n"
					elif [[ -n $m_MountPoint ]] || [[ "$m_MountPoint" != "" ]] || [[ ! "$m_MountPoint" =~ " " ]]
					then
						MountPartsString+=" --> *$partfsformat --> (use as swap) (swap enabled)\n"
						m_MountedPartitions+=("${m_partitions[0]}")
					fi
					Reformat_Disks+=("${m_partitions[0]}")
				elif [[ "$m_parttypename" == "Linux filesystem" ]] || [[ "$m_parttypename" == "Linux" ]]
				then
					if [[ "$partfsformat" == "$linuxfs" ]]
					then
						MountPartsString+=" --> *$partfsformat"
					elif [[ "$partfsformat" != "$linuxfs" ]]
					then
						MountPartsString+=" --> *($partfsformat -> $linuxfs)"
					fi

					if [[ -z $m_MountPoint ]]
					then
						MountPartsString+=" --> /mnt/\n"
					elif [[ -n $m_MountPoint ]] || [[ "$m_MountPoint" != "" ]] || [[ ! "$m_MountPoint" =~ " " ]]
					then
						MountPartsString+=" --> $m_MountPoint (mounted)\n"
						m_MountedPartitions+=("${m_partitions[0]}")
					fi
					Reformat_Disks+=("${m_partitions[0]}")
				elif [[ "$m_parttypename" == "Linux home" ]]
				then
					if [[ "$partfsformat" == "$linuxfs" ]]
					then
						MountPartsString+=" --> *$partfsformat"
					elif [[ "$partfsformat" != "$linuxfs" ]]
					then
						MountPartsString+=" --> *($partfsformat -> $linuxfs)"
					fi

					if [[ -z $m_MountPoint ]]
					then
						MountPartsString+=" --> /mnt/home/\n"
					elif [[ -n $m_MountPoint ]] || [[ "$m_MountPoint" != "" ]] || [[ ! "$m_MountPoint" =~ " " ]]
					then
						MountPartsString+=" --> $m_MountPoint (mounted)\n"
						m_MountedPartitions+=("${m_partitions[0]}")
					fi
					Reformat_Disks+=("${m_partitions[0]}")
				fi
			elif [[ -z $partfsformat ]] || [[ "$partfsformat" == "" ]] || [[ "$partfsformat" =~ " " ]]
			then
				if [[ "$m_parttypename" == "EFI System" ]] || [[ "$m_parttypename" == "EFI (FAT-12/16/32)" ]]
				then
					MountPartsString+=" --> +FAT32 --> /mnt/boot\n"
					Format_Disks+=("${m_partitions[0]}")
				elif [[ "$m_parttypename" == "Linux swap" ]]
				then
					MountPartsString+=" --> +swap --> (use as swap)\n"
					Format_Disks+=("${m_partitions[0]}")
				elif [[ "$m_parttypename" == "Linux filesystem" ]] || [[ "$m_parttypename" == "Linux" ]]
				then
					MountPartsString+=" --> +$linuxfs --> /mnt/\n"
					Format_Disks+=("${m_partitions[0]}")
				elif [[ "$m_parttypename" == "Linux home" ]]
				then
					MountPartsString+=" --> +$linuxfs --> /mnt/home\n"
					Format_Disks+=("${m_partitions[0]}")
				fi
			fi
			MountParts+=("$MountPartsString")
			unset MountPartsString m_MountPoint

		# create array of disk and partition info strings to view as a tree structure in the mount confirmation dialog when partitions are greater than one
		elif [[ ${#m_partitions[@]} -gt 1 ]]
		then
			for l in ${m_partitions[@]}
			do
				local partfsformat=$(lsblk /dev/$l -nlo fsver,fstype | sed 's/FAT32 vfat/FAT32/g;s/1.0   ext4/ext4/g;s/1     swap/swap/g')
				local partsize=$(lsblk /dev/$l -nlo size | sed 's/^\s*//g;s/[mM]/ MB/g;s/[gG]/ GB/g;s/[tT]/ TB/g')
				local m_partlabel=$(lsblk /dev/$l -nlo partlabel)
				local m_parttypename=$(lsblk /dev/$l -nlo parttypename)
				local m_MountPoint=$(lsblk /dev/$l -nlo mountpoint)

				if [[ "$l" != "${m_partitions[-1]}" ]]
				then
					MountPartsString+="  |-/dev/$l --> "
				elif [[ "$l" == "${m_partitions[-1]}" ]]
				then
					MountPartsString+="  \`-/dev/$l --> "
				fi
				MountPartsString+="$partsize --> $m_partlabel --> $m_parttypename"

				if [[ -z $partfsformat ]] || [[ "$partfsformat" == "" ]] || [[ $partfsformat =~ " " ]]
				then
					if [[ "$m_parttypename" == "EFI System" ]] || [[ "$m_parttypename" == "EFI (FAT-12/16/32)" ]]
					then
						MountPartsString+=" --> +FAT32 --> /mnt/boot\n"
						Format_Disks+=("$l")
					elif [[ "$m_parttypename" == "Linux swap" ]]
					then
						MountPartsString+=" --> +swap --> (use as swap)\n"
						Format_Disks+=("$l")
					elif [[ "$m_parttypename" == "Linux filesystem" ]] || [[ "$m_parttypename" == "Linux" ]]
					then
						MountPartsString+=" --> +$linuxfs --> /mnt\n"
						Format_Disks+=("$l")
					elif [[ "$m_parttypename" == "Linux home" ]]
					then
						MountPartsString+=" +$linuxfs --> /mnt/home\n"
						Format_Disks+=("$l")
					fi
				elif [[ -n $partfsformat ]] || [[ "$partfsformat" != "" ]] || [[ ! $partfsformat =~ " " ]]
				then
					if [[ "$m_parttypename" == "EFI System" ]] || [[ "$m_parttypename" == "EFI (FAT-12/16/32)" ]]
					then
						MountPartsString+=" --> *FAT32 --> "
						if [[ -z $m_MountPoint ]] || [[ "$m_MountPoint" == "" ]] || [[ "$m_MountPoint" =~ " " ]]
						then
							MountPartsString+="/mnt/boot\n"
						elif [[ -n $m_MountPoint ]] || [[ "$m_MountPoint" != "" ]] || [[ ! "$m_MountPoint" =~ " " ]]
						then
							MountPartsString+="$m_MountPoint (mounted)\n"
							m_MountedPartitions+=("$l")
						fi
						Reformat_Disks+=("$l")
					elif [[ "$m_parttypename" == "Linux swap" ]]
					then
						MountPartsString+=" --> *swap --> "
						if [[ -z $m_MountPoint ]] || [[ "$m_MountPoint" == "" ]] || [[ "$m_MountPoint" =~ " " ]]
						then
							MountPartsString+="(use as swap)\n"
						elif [[ -n $m_MountPoint ]] || [[ "$m_MountPoint" != "" ]] || [[ ! "$m_MountPoint" =~ " " ]]
						then
							MountPartsString+="(use as swap) (swap enabled)\n"
							m_MountedPartitions+=("$l")
						fi
						Reformat_Disks+=("$l")
					elif [[ "$m_parttypename" == "Linux filesystem" ]] || [[ "$m_parttypename" == "Linux" ]]
					then
						if [[ "$partfsformat" == "$linuxfs" ]]
						then
							MountPartsString+=" --> *$partfsformat --> "
						elif [[ "$partfsformat" != "$linuxfs" ]]
						then
							MountPartsString+=" --> *($partfsformat -> $linuxfs) --> "
						fi

						if [[ -z $m_MountPoint ]] || [[ "$m_MountPoint" == "" ]] || [[ "$m_MountPoint" =~ " " ]]
						then
							MountPartsString+="/mnt/\n"
						elif [[ -n $m_MountPoint ]] || [[ "$m_MountPoint" != "" ]] || [[ ! "$m_MountPoint" =~ " " ]]
						then
							MountPartsString+="$m_MountPoint (mounted)\n"
							m_MountedPartitions+=("$l")
						fi						
						Reformat_Disks+=("$l")
					elif [[ "$m_parttypename" == "Linux home" ]]
					then
						if [[ "$partfsformat" == "$linuxfs" ]]
						then
							MountPartsString+=" --> *$partfsformat --> "
						elif [[ "$partfsformat" != "$linuxfs" ]]
						then
							MountPartsString+=" --> *($partfsformat -> $linuxfs) --> "
						fi

						if [[ -z $m_MountPoint ]] || [[ "$m_MountPoint" == "" ]] || [[ "$m_MountPoint" =~ " " ]]
						then
							MountPartsString+="/mnt/home\n"
						elif [[ -n $m_MountPoint ]] || [[ "$m_MountPoint" != "" ]] || [[ ! "$m_MountPoint" =~ " " ]]
						then
							MountPartsString+="$m_MountPoint (mounted)\n"
							m_MountedPartitions+=("$l")
						fi
						Reformat_Disks+=("$l")
					fi
				fi
			done
			MountParts+=("$MountPartsString")
			unset MountPartsString
		fi
		unset m_partitions
	done

	local MountPartsString="${MountParts[*]}"


	# create dialogs based on the array of format, reformat and mountedpartitions arrays:
	# dialog to format and mount all disks
	if [[ -z ${Reformat_Disks[@]} ]] && ([[ "${Format_Disks[@]}" == "${m_MountPartitionsTextsTemp[@]}" ]] || [[ ${#Format_Disks[@]} -eq ${#m_MountPartitionsTextsTemp[@]} ]])
	then
		dialog --scrollbar --yes-label "Back" --no-label "Format & Mount" --title "partition mount confirmation" --yesno "1) +Format - Will format the partition with specified filesystem format. Reformatting will\n             not apply here.\n2) *Format - If the \"Re-Format\" is selected it will reformat the partition using existing filesystem\n             format wiping the partition.\nFormat:\n  Disk\n  \`-  Partition --> Size --> Partition Label --> Filesystem --> (+|*)Format --> MountPoint\n${MountPartsString[*]}\n\n" 20 110
		case $? in
			0) PartitionDisk ;;
			1)
				for u in ${m_MountPartitionsTextsTemp[@]}
				do
					FormatPartition "$u" "$linuxfs"
				done
				MountPartitions m_MountPartitionsTextsTemp
				;;
		esac

	# dialog to reformat all unformatted disks and mount all disks
	elif [[ -n ${Reformat_Disks[@]} ]] && [[ -n ${Format_Disks[@]} ]] && ([[ "${Reformat_Disks[@]}" != "${Format_Disks[@]}" ]] || [[ ${#Reformat_Disks[@]} -ne ${#Format_Disks[@]} ]])
	then
		dialog --scrollbar --ok-label "Back" --cancel-label "Format & Mount" --extra-button --extra-label "Re-Format & Mount" --title "partition mount confirmation" --yesno "1) +Format - Will format the partition with specified filesystem format. Reformatting will\n             not apply here.\n2) *Format - If the \"Re-Format\" is selected it will reformat the partition using existing filesystem.\n3) *(Format_1 -> Format_2) - Will reformat the existing \"Format_1\" filesystem with \"Format_2\" filesystem\n                             partition with different filesystem format.\n\nFormat:\n  Disk\n  \`-  Partition --> Size --> Partition Label --> Filesystem --> (+|*)Format --> MountPoint\n${MountPartsString[*]}\n\n" 20 110
		case $? in
			0) PartitionDisk ;;
			1)
				UnMountPartitions
				for u in ${Format_Disks[@]}
				do
					FormatPartition "$u" "$linuxfs"
				done
				MountPartitions m_MountPartitionsTextsTemp
				;;
			3)
				UnMountPartitions
				for u in ${m_MountPartitionsTextsTemp[@]}
				do
					FormatPartition "$u" "$linuxfs"
				done
				MountPartitions m_MountPartitionsTextsTemp
				;;
		esac

	# dialog to reformat and mount all disks or only mount all disks
	elif [[ -z ${Format_Disks[@]} ]] && ([[ "${Reformat_Disks[@]}" == "${m_MountPartitionsTextsTemp[@]}" ]] || [[ ${#Reformat_Disks[@]} -eq ${#m_MountPartitionsTextsTemp[@]} ]]) && ([[ -z ${m_MountedPartitions[@]} ]] || [[ "${m_MountedPartitions[@]}" != "${m_MountPartitionsTextsTemp[@]}" ]] || [[ ${#m_MountedPartitions[@]} -ne ${#m_MountPartitionsTextsTemp[@]} ]])
	then
		dialog --scrollbar --ok-label "Back" --cancel-label "Mount" --extra-button --extra-label "Re-Format All & Mount" --title "partition mount confirmation" --yesno "1) *Format - If the \"Re-Format\" is selected it will reformat the partition using existing filesystem\n             format wiping the partition.\n2) *(Format_1 -> Format_2) - Will reformat the existing \"Format_1\" filesystem with \"Format_2\" filesystem\n                             partition with different filesystem format.\n\nFormat:\n  Disk\n  \`-  Partition --> Size --> Partition Label --> Filesystem --> (+|*)Format --> MountPoint\n${MountPartsString[*]}\n\n" 20 110
		case $? in
			0) PartitionDisk ;;
			1) MountPartitions m_MountPartitionsTextsTemp ;;
			3)
				UnMountPartitions
				for u in ${m_MountPartitionsTextsTemp[@]}
				do
					FormatPartition "$u" "$linuxfs"
				done
				MountPartitions m_MountPartitionsTextsTemp
				;;
		esac		

	# dialog to reformat and mount all disks or skip this step if all relevant operations are done
	elif [[ -z ${Format_Disks[@]} ]] && ([[ "${Reformat_Disks[@]}" == "${m_MountPartitionsTextsTemp[@]}" ]] || [[ ${#Reformat_Disks[@]} -eq ${#m_MountPartitionsTextsTemp[@]} ]]) && ([[ -n ${m_MountedPartitions[@]} ]] || [[ "${m_MountedPartitions[@]}" == "${m_MountPartitionsTextsTemp[@]}" ]] || [[ ${#m_MountedPartitions[@]} -eq ${#m_MountPartitionsTextsTemp[@]} ]])
	then
		dialog --scrollbar --ok-label "Back" --cancel-label "skip" --extra-button --extra-label "Re-Format All & Mount" --title "partition mount confirmation" --yesno "1) *Format - If the \"Re-Format\" is selected it will reformat the partition using existing filesystem\n             format wiping the partition.\n2) *(Format_1 -> Format_2) - Will reformat the existing \"Format_1\" filesystem with \"Format_2\" filesystem\n                             partition with different filesystem format.\n\nFormat:\n  Disk\n  \`-  Partition --> Size --> Partition Label --> Filesystem --> (+|*)Format --> MountPoint\n${MountPartsString[*]}\n\n" 20 110
		case $? in
			0) PartitionDisk ;;
			3)
				UnMountPartitions
				for u in ${m_MountPartitionsTextsTemp[@]}
				do
					wipefs "/dev/$u" | GuageMeter "Wiping partition /dev/$u" 1
				done

				for u in ${m_MountPartitionsTextsTemp[@]}
				do
					FormatPartition "$u" "$linuxfs"
				done
				MountPartitions m_MountPartitionsTextsTemp
				;;
		esac
		
	fi
	unset MountParts Format_Disks ReFormat_Disks
}

FormatPartition(){
	local Partition=$1
	local fsformat=$2
	local m_parttypename="$(lsblk "/dev/$Partition" -dlno parttypename)"
	local m_existingfs="$(lsblk "/dev/$Partition" -dlno fstype)"

	# formats partition if filesystem does not exist. reformats partition if filesystem exists
	case $m_parttypename in
		"Linux filesystem"|"Linux home"|"Linux")
			if [[ -z $m_existingfs ]] || [[ "$m_existingfs" == "" ]] || [[ "$m_existingfs" =~ " " ]]
			then
				mkfs.$fsformat "/dev/$Partition" &>/dev/null | GuageMeter "Formatting partition /dev/$Partition with $fsformat" 1
			elif [[ -n $m_existingfs ]] || [[ "$m_existingfs" != "" ]] || [[ ! "$m_existingfs" =~ " " ]]
			then
				printf "y\n" | mkfs.$fsformat "/dev/$Partition" &>/dev/null | GuageMeter "Reformatting partition /dev/$Partition with $fsformat" 1
			fi
			;;
		"EFI System"|"EFI (FAT-12/16/32)")
			if [[ -z $m_existingfs ]] || [[ "$m_existingfs" == "" ]] || [[ "$m_existingfs" =~ " " ]]
			then
				mkfs.fat -F32 "/dev/$Partition" &>/dev/null | GuageMeter "Formatting partition /dev/$Partition with FAT32" 1
			elif [[ -n $m_existingfs ]] || [[ "$m_existingfs" != "" ]] || [[ ! "$m_existingfs" =~ " " ]]
			then
				printf "y\n" | mkfs.fat -F32 "/dev/$Partition" &>/dev/null | GuageMeter "Reformatting partition /dev/$Partition with FAT32" 1
			fi
			;;
		"Linux swap")
			if [[ -z $m_existingfs ]] || [[ "$m_existingfs" == "" ]] || [[ "$m_existingfs" =~ " " ]]
			then
				mkswap "/dev/$Partition" &>/dev/null | GuageMeter "creating swap filesystem on partition /dev/$Partition" 1
			elif [[ -n $m_existingfs ]] || [[ "$m_existingfs" != "" ]] || [[ ! "$m_existingfs" =~ " " ]]
			then
				printf "y\n" | mkswap "/dev/$Partition" &>/dev/null | GuageMeter "Rewriting swap filesystem on partition /dev/$Partition" 1
			fi
			;;
	esac
	unset Partition fsformat m_parttypename
}

UnMountPartitions(){

	# disable all swaps
	swapoff -a

	# unmount order.
	# 1 - /mnt/home
	# 2 - /mnt/boot
	# 3 - /mnt/
	if [[ -d /mnt/home ]]
	then
		if mountpoint /mnt/home &>/dev/null
		then
			umount /mnt/home &>/dev/null
		fi
	fi

	if mountpoint /mnt/boot &>/dev/null
	then
		umount /mnt/boot &>/dev/null
		rm -rf /mnt/boot &>/dev/null
		if mountpoint /mnt/ &>/dev/null
		then
			umount /mnt/ &>/dev/null
		fi
	elif ! mountpoint /mnt/boot &>/dev/null
	then
		if [[ -d /mnt/boot ]]
		then
			rm -rf /mnt/boot &>/dev/null
		fi
		if mountpoint /mnt/ &>/dev/null
		then
			umount /mnt/ &>/dev/null
		fi
	fi
}

MountPartitions(){
	local PartitionsArgs=$1[@]
	local Partitions=${!PartitionsArgs}
	local mounted=()
	local fail_drive=()
	local already_mounted=()
	local mountfails=()
	unset PartitionsArgs

	# mount order
	# 1 - /mnt/
	# 2 - /mnt/boot
	# 3 - /mnt/home

	while ( ! mountpoint /mnt &>/dev/null ) || ( [[ ! -d /mnt/boot ]] || ( ! mountpoint /mnt/boot &>/dev/null ) )
	do
		if ( ! mountpoint /mnt &>/dev/null )
		then
			for k in ${Partitions[@]}
			do
				local partfsformat="$(lsblk "/dev/$k" -dlno fstype,fsver | awk '{ print $1" "$2 }' | sed 's/vfat FAT32/FAT32/g;s/ 1.0//g;s/swap 1/swap/g')"
				local partfsformat2="$(lsblk "/dev/$k" -dlno fstype,fsver | awk '{ print $1" "$2 }')"
				local m_parttypenametemp="$(lsblk /dev/$k -nlo parttypename | grep -ie 'linux filesystem\|swap\|linux.*home' | sed -E 's/\s{13}/  /g')"
				local m_sizetemp="$(lsblk /dev/$k -nlo size | sed 's/^\s*//g')"
				local m_partlabeltemp="$(lsblk /dev/$k -nlo partlabel | sed -E 's/\s{13}/  /g')"

				if [[ -z $m_partlabeltemp ]] || [[ "$m_partlabeltemp" == "" ]] || [[ "$m_partlabeltemp" =~ " " ]]
				then
					m_partlabeltemp="No Label"
				fi

				if [[ "$m_parttypenametemp" == "Linux filesystem" ]] || [[ "$m_parttypenametemp" == "Linux" ]]
				then
					case $partfsformat in
						"ext4"|"ext3"|"ext2"|"xfs"|"zfs"|"bfs"|"btrfs"|"jfs")
							mount /dev/$k /mnt
							case $? in
								0)
									if [[ ! -d /mnt/boot ]]
									then
										mkdir /mnt/boot
									fi
									mounted+=("/dev/$k --> $m_sizetemp --> $partfsformat - $m_parttypenametemp ($m_partlabeltemp) --> $(lsblk /dev/$k -nlo mountpoint )\n")
									break
									;;
								1)  
									mountfails+=("/dev/$k --> $m_sizetemp --> $partfsformat - $m_parttypenametemp ($m_partlabeltemp) --> $(lsblk /dev/$k -nlo mountpoint )\n")
									break
									;;
								32)
									already_mounted+=("/dev/$k --> $m_sizetemp --> $partfsformat - $m_parttypenametemp ($m_partlabeltemp) --> $(lsblk /dev/$k -nlo mountpoint )\n")
									break
									;;
							esac
							;;
					esac
				fi
				unset m_parttypename partfsformat m_parttypenametemp m_sizetemp m_partlabeltemp
			done

			if ! mountpoint /mnt &>/dev/null
			then
				dialog --msgbox "could not mount '/dev/${fail_drive[0]}' to '/'. Therefore cannot mount other partitions. you can manually try mounting the partition or changing the partition type to the right partition type and format it with the relevant filesystem and mount it" 0 0
				break
			fi
		elif ( mountpoint /mnt &>/dev/null )
		then
			if [[ -d /mnt/boot ]]
			then
				if ( ! mountpoint /mnt/boot/ &>/dev/null )
				then
					for k in ${Partitions[@]}
					do
						local partfsformat="$(lsblk "/dev/$k" -dlno fstype,fsver | awk '{ print $1" "$2 }' | sed 's/vfat FAT32/FAT32/g;s/ 1.0//g;s/swap 1/swap/g')"
						local partfsformat2="$(lsblk "/dev/$k" -dlno fstype,fsver | awk '{ print $1" "$2 }')"
						local m_parttypenametemp="$(lsblk /dev/$k -nlo parttypename | grep -ie 'efi\|linux filesystem\|^linux$' | sed -E 's/\s{13}/  /g')"
						local m_sizetemp="$(lsblk /dev/$k -nlo size | sed 's/^\s*//g')"
						local m_partlabeltemp="$(lsblk /dev/$k -nlo partlabel | sed -E 's/\s{13}/  /g')"

						if [[ -z $m_partlabeltemp ]] || [[ "$m_partlabeltemp" == "" ]] || [[ "$m_partlabeltemp" =~ " " ]]
						then
							m_partlabeltemp="No Label"
						fi

						if [[ "$m_parttypenametemp" == "EFI System" ]] || [[ "$partfsformat" == "FAT32" ]] || [[ "$partfsformat2" == "vfat FAT32" ]]
						then
							mount /dev/$k /mnt/boot
							case $? in
								0) 
									mounted+=("/dev/$k --> $m_sizetemp --> $partfsformat - $m_parttypenametemp ($m_partlabeltemp) --> $(lsblk /dev/$k -nlo mountpoint )\n")
									break
									;;
								1) 
									dialog --msgbox "could not mount disk /dev/$k/ (EFI partition) to /mnt/boot" 0 0
									mountfails+=("/dev/$k --> $m_sizetemp --> $partfsformat - $m_parttypenametemp ($m_partlabeltemp) --> $(lsblk /dev/$k -nlo mountpoint )\n")
									fail_drive+=("$k")
									break
									;;
								32)
									already_mounted+=("/dev/$k --> $m_sizetemp --> $partfsformat - $m_parttypenametemp ($m_partlabeltemp) --> $(lsblk /dev/$k -nlo mountpoint )\n")
									break
									;;
							esac
						fi
						unset m_parttypename partfsformat m_parttypenametemp m_sizetemp m_partlabeltemp
					done
					if ( ! mountpoint /mnt/boot/ &>/dev/null )
					then
						dialog --msgbox "could not mount /dev/${fail_drive[0]} (EFI Partition) to /mnt/boot" 0 0
						break
					fi
				fi
			elif [[ ! -d /mnt/boot ]]
			then
				mkdir /mnt/boot
				for k in ${Partitions[@]}
				do
					local partfsformat="$(lsblk "/dev/$k" -dlno fstype,fsver | awk '{ print $1" "$2 }' | sed 's/vfat FAT32/FAT32/g;s/ 1.0//g;s/swap 1/swap/g')"
					local partfsformat2="$(lsblk "/dev/$k" -dlno fstype,fsver | awk '{ print $1" "$2 }')"
					local m_parttypenametemp="$(lsblk /dev/$k -nlo parttypename | grep -ie 'EFI System' | sed -E 's/\s{13}/  /g')"
					local m_sizetemp="$(lsblk /dev/$k -nlo size | sed 's/^\s*//g')"
					local m_partlabeltemp="$(lsblk /dev/$k -nlo partlabel | sed -E 's/\s{13}/  /g')"

					if [[ -z $m_partlabeltemp ]] || [[ "$m_partlabeltemp" == "" ]] || [[ "$m_partlabeltemp" =~ " " ]]
					then
						m_partlabeltemp="No Label"
					fi

					if [[ "$m_parttypenametemp" == "EFI System" ]] || [[ "$partfsformat" == "FAT32" ]] || [[ "$partfsformat2" == "vfat FAT32" ]]
					then
						mount /dev/$k /mnt/boot
						case $? in
							0)
								mounted+=("/dev/$k --> $m_sizetemp --> $partfsformat - $m_parttypenametemp ($m_partlabeltemp) --> $(lsblk /dev/$k -nlo mountpoint )\n")
								break
								;;
							1) 
								mountfails+=("/dev/$k --> $m_sizetemp --> $partfsformat - $m_parttypenametemp ($m_partlabeltemp) --> $(lsblk /dev/$k -nlo mountpoint )\n")
								fail_drive+=("$k")
								break 
								;;
							32)
								already_mounted+=("/dev/$k --> $m_sizetemp --> $partfsformat - $m_parttypenametemp ($m_partlabeltemp) --> $(lsblk /dev/$k -nlo mountpoint )\n")
								break
								;;
						esac
						# break
					fi
					unset m_parttypename partfsformat m_parttypenametemp m_sizetemp m_partlabeltemp
				done
				if [[ ! -d /mnt/boot ]]
				then
					dialog --msgbox "could not create /mnt/boot. Therefore cannot mount /dev/${fail_drive[0]} (EFI Partition)" 0 0
					break
				elif ( ! mountpoint /mnt/boot &>/dev/null )
				then
					dialog --msgbox "could not mount /dev/${fail_drive[0]} (EFI Partition) to /mnt/boot" 0 0
					break
				fi
			fi
		fi
	done

	if ( mountpoint /mnt &>/dev/null ) && ( mountpoint /mnt/boot &>/dev/null )
	then
		local homepart
		for t in ${Partitions[@]}
		do
			local m_parttypename="$(lsblk "/dev/$t" -dlno parttypename)"
			local partfsformat="$(lsblk "/dev/$t" -dlno fstype,fsver | awk '{ print $1" "$2 }' | sed 's/swap 1/swap/g;s/ 1.0//g')"
			local m_parttypenametemp="$(lsblk /dev/$t -nlo parttypename | grep -ie 'home' | sed -E 's/\s{13}/  /g')"
			local m_sizetemp="$(lsblk /dev/$t -nlo size | sed 's/^\s*//g')"
			local m_partlabeltemp="$(lsblk /dev/$t -nlo partlabel | sed -E 's/\s{13}/  /g')"

			if [[ -z $m_partlabeltemp ]] || [[ "$m_partlabeltemp" == "" ]] || [[ "$m_partlabeltemp" =~ " " ]]
			then
				m_partlabeltemp="No Label"
			fi

			if [[ "$m_parttypenametemp" == "Linux home" ]]
			then
				homepart="$t"
				mkdir /mnt/home
				mount /dev/$t /mnt/home
				case $? in
					0)
						mounted+=("/dev/$t --> $m_sizetemp --> $partfsformat - $m_parttypenametemp ($m_partlabeltemp) --> $(lsblk /dev/$t -nlo mountpoint )\n")
						unset homepart
						break
						;;
					1)
						mountfails+=("/dev/$t --> $m_sizetemp --> $partfsformat - $m_parttypenametemp ($m_partlabeltemp) --> $(lsblk /dev/$t -nlo mountpoint )\n")
						dialog --msgbox "could not mount home partition /dev/$homepart" 0 0
						unset homepart
						break
						;;
					32)
						already_mounted+=("/dev/$k --> $m_sizetemp --> $partfsformat - $m_parttypenametemp ($m_partlabeltemp) --> $(lsblk /dev/$k -nlo mountpoint )\n")
						break
						;;
				esac
			fi
			unset m_parttypename partfsformat m_parttypenametemp m_sizetemp m_partlabeltemp
		done
	fi

	local enabled_swap=()
	local disabled_swap=()
	local swap_parts=()
	local swap_already_enabled=()
	local swapstatetext=""

	for k in ${Partitions[@]}
	do
		local m_parttypename="$(lsblk "/dev/$k" -dlno parttypename)"
		local partfsformat="$(lsblk "/dev/$k" -dlno fstype,fsver | awk '{ print $1" "$2 }' | sed 's/swap 1/swap/g;s/ 1.0//g')"
		local m_parttypenametemp="$(lsblk /dev/$k -nlo parttypename | grep -ie 'swap' | sed -E 's/\s{13}/  /g')"
		local m_sizetemp="$(lsblk /dev/$k -nlo size | sed 's/^\s*//g')"
		local m_partlabeltemp="$(lsblk /dev/$k -nlo partlabel | sed -E 's/\s{13}/  /g')"

		if [[ -z $m_partlabeltemp ]] || [[ "$m_partlabeltemp" == "" ]] || [[ "$m_partlabeltemp" =~ " " ]]
		then
			m_partlabeltemp="No Label"
		fi

		if [[ "$m_parttypename" == "Linux swap" ]] || [[ "$partfsformat" == "swap" ]]
		then
			swap_parts+=("$k")
			swapon "/dev/$k"
			case $? in
				0) enabled_swap+=("/dev/$k --> $m_sizetemp --> $m_parttypenametemp ($m_partlabeltemp) --> swap enabled") ;;
				255)
					swap_already_enabled+=("/dev/$k --> $m_sizetemp --> $partfsformat - $m_parttypenametemp ($m_partlabeltemp) --> $(lsblk /dev/$k -nlo mountpoint )\n")
					break
					;;
				1) disabled_swap+=("/dev/$k --> $m_sizetemp --> $m_parttypenametemp ($m_partlabeltemp)") ;;
			esac
		fi
		unset m_parttypename partfsformat m_parttypenametemp m_sizetemp m_partlabeltemp m_parttypename partfsformat
	done

	local mountdialogstring=""

	# fresh mount
	if [[ -n ${mounted[@]} ]] && [[ -z ${fail_drive[@]} ]] && [[ -z ${already_mounted[@]} ]] && [[ -z ${mountfails[@]} ]] && [[ -n ${enabled_swap[@]} ]] && [[ -z ${disabled_swap[@]} ]] && [[ -z ${swap_already_enabled[@]} ]]
	then
		mountdialogstring="partitions mounted:\n${mounted[*]}${enabled_swap[*]}"

	# all already mounted
	elif [[ -z ${mounted[@]} ]] && [[ -z ${fail_drive[@]} ]] && [[ -n ${already_mounted[@]} ]] && [[ -z ${mountfails[@]} ]] && [[ -z ${enabled_swap[@]} ]] && [[ -z ${disabled_swap[@]} ]] && [[ -n ${swap_already_enabled[@]} ]]
	then
		mountdialogstring="partitions already mounted:\n${already_mounted[*]}${swap_already_enabled[*]}"

	# some already mounted with fails
	elif [[ -n ${mounted[@]} ]] && [[ -n ${fail_drive[@]} ]] && [[ -n ${already_mounted[@]} ]] && [[ -n ${mountfails[@]} ]] && [[ -n ${enabled_swap[@]} ]] && [[ -n ${disabled_swap[@]} ]] && [[ -n ${swap_already_enabled[@]} ]]
	then
		mountdialogstring="partitions mounted:\n${mounted[*]}${enabled_swap[*]}\npartitions already mounted:\n${already_mounted[*]}${swap_already_enabled[*]}\npartitions failed to mount:\n${fail_drive[*]}${disabled_swap[*]}"

	# some already mounted without fails
	elif [[ -n ${mounted[@]} ]] && [[ -z ${fail_drive[@]} ]] && [[ -n ${already_mounted[@]} ]] && [[ -n ${mountfails[@]} ]] && [[ -n ${enabled_swap[@]} ]] && [[ -z ${disabled_swap[@]} ]] && [[ -n ${swap_already_enabled[@]} ]]
	then
		mountdialogstring="partitions mounted:\n${mounted[*]}${enabled_swap[*]}\npartitions already mounted:\n${already_mounted[*]}${swap_already_enabled[*]}"
	fi
	dialog --scrollbar --msgbox "$mountdialogstring" 10 90
	# unset mountdialogstring
}


# Disk Info
DiskListTemp(){
	local Disk=$1
	if [[ -n "$Disk" ]]
	then
		lsblk "/dev/$Disk" -dno name,size,pttype,vendor,model | grep -iv 'fd[0-9]\|loop\|sr[0-9]*' | sed -E 's/\s{8}/ none   /g'
	elif [[ -z $1 ]]
	then
		lsblk -dno name,size,pttype,vendor,model | grep -iv 'fd[0-9]\|loop\|sr[0-9]*' | sed -E 's/\s{8}/ none   /g'
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

	local DISKS_WITHOUT_PARTITIONS_PRESENT_EXIT_CODE=$2

	local m_NoPartsDisks=(${m_Disks[@]})
	m_NoPartsDisks=($(DisksWithoutPartitions m_NoPartsDisks))

	local m_DiskParts=(${m_Disks[@]})
	m_DiskParts=($(DisksWithPartitions m_DiskParts))

	case $DISKS_WITHOUT_PARTITIONS_PRESENT_EXIT_CODE in
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
							0)
								unset DISKSWITHOUTPARTITIONSPRESENT_EXIT_CODE
								MountViewPartitions m_Disks
								;;
							1)
								unset DISKSWITHOUTPARTITIONSPRESENT_EXIT_CODE
								CheckEditMount m_Disks $DISKSWITHOUTPARTITIONSPRESENT_EXIT_CODE
								;;
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
							0)
								unset DISKSWITHOUTPARTITIONSPRESENT_EXIT_CODE
								MountViewPartitions m_Disks
								;;
							1)
								unset DISKSWITHOUTPARTITIONSPRESENT_EXIT_CODE
								CheckEditMount m_Disks $DISKSWITHOUTPARTITIONSPRESENT_EXIT_CODE
								;;
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
	local m_Disks=(${!disksArgs})
	unset disksArgs

	local diskeditors=()

	# disk editor array for use in dialog
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
	local DiskEditor
	DiskEditor="$(dialog --no-tags --cancel-label "Back" --menu "Disk Editor Menu\n\nSelect a Disk Editor to Edit the $disk ${disksTemp[*]}" 0 0 0 "${diskeditors[@]}" 3>&1 1>&2 2>&3)"
	case $? in
		1) PartitionDisk ;;
		0)
			local m_NonePartDisks=()
			dialog --no-label "Back" --yes-label "OK" --yesno "					 partition type -----> partition filesystem format\n\nPartitions to be created and formatted to:\n\n  Mandatory:\n   1) EFI system partition -> FAT32(This is where the bootloader and the kernel resides)\n   2) Linux filesystem -----> ext4/ext3/ext2/xfs/zfs/bfs/btrfs/jfs (This is the linux root partition)\n\n  Optional but recommended:\n   1) Linux swap -> swap (used when machine runs out of RAM/physical memory\n\n  Optional:\n   1) Linux home -> Same format as Linux filesystem partition (used as storage unit for home directory of all users\n                                                               except root)" 0 0
			case $? in
				0)
					local PartProbeDisks=()
					for i in "${m_Disks[@]}"
					do
						reset
						# center and bold text
						printf "\E[1m\t\t\t\t\t\t\t\tEditing Disk '/dev/$i' with $DiskEditor\n\n\n\E[m"
						"$DiskEditor" "/dev/$i"
						local m_DiskPartCheck=()
						m_DiskPartCheck=($(DiskPartInfoTemp "$i" | awk '{ print $1 }'))
						if [[ -n "${m_DiskPartCheck[@]}" ]]
						then
							m_NonePartDisks+=("$i")
						elif [[ -z "${m_DiskPartCheck[@]}" ]]
						then
							PartProbeDisks+=("$i")
						fi
						unset m_DiskPartCheck
					done
					partprobe "${PartProbeDisks[@]}"
					;;
				1) PartitionDisk ;;
			esac
			;;
	esac
	unset diskeditors
}

WritePartitionTable(){
	local PartTableTemp=()
	local PartTable
	PartTableTemp+=("GPT" "supports 128 primary partitions, mutiple bootloaders, storage more than 2TB")
	PartTableTemp+=("MBR" "supports 4 primary partitions, max storage of 2TB")
	PartTable="$(dialog --cancel-label "Back" --menu "Partition Table Menu\n\nSelect the partition Table to write" 0 0 0 "${PartTableTemp[@]}" 3>&1 1>&2 2>&3)"
	case $? in
		0)
			local m_DisksArgs=$1[@]
			local m_Disks=("${!m_DisksArgs}")
			unset m_DisksArgs

			# write partition table
			local diskhave=($(TempArrayWithAmpersandHasHaveTexts ${#m_Disks[@]}))
			local m_DisksTemp=("${m_Disks[@]}")
			m_DisksTemp=($(TempArrayWithAmpersand m_DisksTemp))
			for b in ${m_Disks[@]}
			do
				local GuageMeterText=""
				local m_pttype=$(lsblk /dev/$b -dnlo pttype)
				if [[ -n $pttype ]] || [[ "$pttype" != "" ]] || [[ ! "$pttype" =~ " " ]]
				then
					parted "/dev/$b" mktable "$PartTable" ---pretend-input-tty <<< "y" &>/dev/null # | GuageMeter "Re-Writing $m_pttype with $PartTable on disk /dev/$b" 1
					partprobe /dev/$b
				elif [[ -z $pttype ]] || [[ "$pttype" == "" ]] || [[ "$pttype" =~ " " ]]
				then
					parted "/dev/$b" mktable "$PartTable" | GuageMeter "Setting $PartTable on disk /dev/$b" 1
					partprobe /dev/$b
				fi
			done
			dialog --msgbox "$PartTable Partiton Table set on ${diskhave[0]} ${m_DisksTemp[*]}" 0 0 3>&1 1>&2 2>&3
			unset diskhave
			;;
		1) PartitionDisk ;;
	esac
}

# maybe the wrong function name for the purpose it serves but this is where disks and the options to manipulate the disks are shown
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


	# disk name in key value pair
	local DiskModelString=""
	for i in ${DiskList[@]}
	do
		DiskModelString="${DiskVendor[$i]} ${DiskModelTemp[$i]}"
		DiskName[$i]="$DiskModelString"
		DiskModelString=""
	done

	# disk info in key value pair
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

	local m_diskswithparttable=()
	local m_diskswithparttable=()
	for o in ${Disks[@]}
	do
		IsPartitionTablePresent $o
		case $? in
			0) m_diskswithparttable+=("$o") ;;
		esac
	done

	if [[ -n ${m_diskswithparttable[@]} ]]
	then
		local REWRITE_PTTYPE_EXIT_CODE
		if [[ ${#m_diskswithparttable[@]} -eq 1 ]]
		then
			dialog --yesno "disk ${m_diskswithparttable[*]} contains a partition table. Re-Write the disk with another partition table?" 0 0
			REWRITE_PTTYPE_EXIT_CODE=$?
		elif [[ ${#m_diskswithparttable} -gt 1 ]]
		then
			local m_diskswithparttableTemp
			m_diskswithparttableTemp=("${m_diskswithparttable[@]}")
			m_diskswithparttableTemp=($(TempArrayWithAmpersand m_diskswithparttableTemp))
			local diskshave=($(TempArrayWithAmpersandHasHaveTexts ${#m_diskswithparttable[@]}))
			REWRITE_PTTYPE_EXIT_CODE=$?
			dialog --yesno "${diskshave[0]} ${m_diskswithparttableTemp[*]} contains partition tables. Re-Write the ${diskshave[0]} with another partition table?" 0 0
			unset m_diskswithparttableTemp diskshave
		fi
		case $REWRITE_PTTYPE_EXIT_CODE in
			0) WritePartitionTable m_diskswithparttable ;;
		esac
		unset REWRITE_PTTYPE_EXIT_CODE
	fi

	# check number of partitions and go to select disks or edit selected disks
	if [[ ${#Disks[@]} -eq 1 ]]
	then
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
					# set partition table if not set
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

				# check for empty disks and edit disks accordingly
				dialog --extra-button --extra-label "Mount" --ok-label "Back" --cancel-label "Edit" --yesno "Select \"Edit\" for Editting and then mounting the partitions of this disk or select \"Mount\" to only select, format and mount existing Linux filesystem/EFI/swap partitions" 0 0
				case $? in
					0) PartitionDisk ;;
					1)
						EditDisk Disks
						DisksWithoutPartitionsPresent Disks
						DISKSWITHOUTPARTITIONSPRESENT_EXIT_CODE=$?
						case $DISKSWITHOUTPARTITIONSPRESENT_EXIT_CODE in
							0) CheckEditMount Disks $DISKSWITHOUTPARTITIONSPRESENT_EXIT_CODE ;;
							1)
								unset DISKSWITHOUTPARTITIONSPRESENT_EXIT_CODE
								MountViewPartitions Disks
								;;
						esac
						unset DISKSWITHOUTPARTITIONSPRESENT_EXIT_CODE
						;;
					3)
						DisksWithoutPartitionsPresent Disks
						CheckEditMount Disks $?
						;;
				esac
			fi
			;;
	esac
}

# View and mount all disk partitions containing only linux install compatible characteristics
MountViewPartitions(){

	# $1 - Disks

	local DisksArgs=$1[@]
	local Disks=(${!DisksArgs})
	unset DisksArgs

	local DisksTemp=("${Disks[@]}")
	local DisksTemp=($(TempArrayWithAmpersand DisksTemp))
	local NoPartDisks=("${Disks[@]}")
	local NoPartDisks=($(DisksWithoutPartitions NoPartDisks))


	local efi_parts
	local linux_fs_parts
	local linux_swap_parts
	local linux_home_parts
	local linux_user_home_parts

	local SelectedPartitions=()
	local DiscardDisks=()
	local DiscardDisksTemp

	# check for partitions containing partition table or discard accordingly
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

	# loop to create an array of strings holding partition info
	for (( a = 0; a < ${#Disks[@]}; a++))
	do
		local PartitionMenuItemFormatText=""
		local DiskPartName=($(DiskPartInfoTemp "${Disks[$i]}" | awk '{ print $1 }'))
		local DiskPartSizeTemp=($(DiskPartInfoTemp "${Disks[$i]}" | awk '{ print $2}'))
		local DiskPartFsTypeTemp=($(DiskPartTypeName "${Disks[$i]}" | awk '{ $1=$2=NULL; gsub("^\\s*",""); for(i=1;i<=NF;i++){ if(i == NF){ print $i" "i} else { print $i } } }'))

		declare -A DiskPartSize
		declare -A DiskPartLabel
		declare -A DiskPartFsType
		declare -A DiskPartFsFormat
		declare -A PartFs

		if [[ -z ${DiskPartSizeTemp[@]} ]] && [[ -z ${DiskPartFsTypeTemp[@]} ]] && [[ -z ${DiskPartName[@]} ]]
	    then
	    	# do not consider partitions not consisting any partition info
	        continue
	    elif [[ -n ${DiskPartSizeTemp[@]} ]] && [[ -n ${DiskPartFsTypeTemp[@]} ]] && [[ -n ${DiskPartName[@]} ]]
    	then
			# array of partitions
			DiskPartName=($(DiskPartInfoTemp "${Disks[$a]}" | awk '{ print $1 }'))

			# Partition Size in key value pair
			for i in ${DiskPartName[@]}
			do
				DiskPartSize["$i"]="$(lsblk /dev/"$i" -nlo size | sed 's/^\s*//g;s/G/ GB/g;s/M/ MB/g;s/T/ TB/')"
			done

			# Partition lable in key value pair
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

			# Partition type in key value pair
			for i in ${DiskPartName[@]}
			do
				DiskPartFsType["$i"]="$(lsblk /dev/"$i" -nlo parttypename | sed 's/^\s*//g')"
			done


			# Partition filesystem in key value pair
			for i in ${DiskPartName[@]}
			do
				local m_fstype="$(lsblk /dev/"$i" -nlo fstype,fsver | awk '{ print $1" "$2 }' | sed 's/swap 1/swap/g;s/ 1.0//g;s/vfat FAT32/FAT32/g')"
				if [[ -z $m_fstype ]] || [[ $m_fstype =~ " " ]]
				then
					PartFs["$i"]="(Will be formatted)"
				elif [[ -n $m_fstype ]] && [[ ! $m_fstype =~ " " ]]
				then
					PartFs["$i"]="$m_fstype"
				fi
				unset m_fstype
			done

			# Partition information in key value pair
			local DiskPartListInfo=()
			for i in ${DiskPartName[@]}
			do
				local partinfo="${DiskPartSize[$i]} | ${DiskPartFsType[$i]} | ${PartFs[$i]} | ${DiskPartLabel[$i]}"
				DiskPartListInfo+=("$i")
				DiskPartListInfo+=("$partinfo")
				DiskPartListInfo+=(0)
				unset partinfo
			done
			unset DiskPartName DiskPartFsTypeTemp DiskPartSize DiskPartLabel DiskPartFsType # PartFs

			# disk info to be shown in MountMenu
			local m_DiskVendor="$(lsblk "/dev/${Disks[$a]}" -dnlo vendor | sed 's/\s*$//g')"
			local m_DiskModel="$(lsblk "/dev/${Disks[$a]}" -dnlo model)"
			local m_DiskSize="$(lsblk "/dev/${Disks[$a]}" -dnlo size | sed 's/G/ GB/g;s/M/ MB/g;s/T/ TB/')"
			local m_DiskNameString="$m_DiskVendor $m_DiskModel"
			unset m_DiskVendor m_DiskModel

			local partition=()

			if [[ ${#Disks[@]} -eq 1 ]]
			then
				partition=($(dialog --ok-label "Mount" --cancel-label "Back" --column-separator "|" --title "Partition Mount Menu" --checklist "Partitions in /dev/${Disks[$a]} ($m_DiskNameString - $m_DiskSize)\n\ncheckbox items format:\nPartition---size---(partition type)---(Filesystem)--(partition label)" 0 0 0 "${DiskPartListInfo[@]}" 3>&1 1>&2 2>&3))
				PARTITION_EXIT_CODE=$?
			elif [[ ${#Disks[@]} -gt 1 ]]
			then
				partition=($(dialog --cancel-label "Back" --column-separator "|" --title "Partition Mount Menu" --extra-button --extra-label "Mount" --checklist "OK - Will discard upcoming disks saving selected partitions of current\n     and prior disks\nMount - Will show partitions of all selected available disks\n\nPartitions in /dev/${Disks[$a]} ($m_DiskNameString - $m_DiskSize)\n\ncheckbox items format:\nPartition---size---(partition type)---(Filesystem)--(partition label)" 0 0 0 "${DiskPartListInfo[@]}" 3>&1 1>&2 2>&3))
				PARTITION_EXIT_CODE=$?
			fi
			unset m_DiskSize m_DiskNameString

			# arrays to hold number of selected partitions based on partition type
			for g in ${partition[@]}
			do
				local fstype="$(lsblk "/dev/$g" -nlo parttypename)"
				if [[ "$fstype" == "EFI System" || "$fstype" == "EFI (FAT-12/16/32)" ]]
				then
					efi_parts+=("$g")
				elif [[ "$fstype" == "Linux filesystem" || "$fstype" == "Linux" ]]
				then
					linux_fs_parts+=("$g")
				elif [[ "$fstype" == "Linux swap" ]]
				then
					linux_swap_parts+=("$g")
				elif [[ "$fstype" == "Linux home" ]]
				then
					linux_home_parts+=("$g")
				elif [[ "$fstype" == "Linux user's home" ]]
				then
					linux_user_home_parts+=("$g")
				fi
				unset fstype
			done

			local DisksSize=$((${#Disks[@]}-1))
			case $PARTITION_EXIT_CODE in
				0)
					# press ok to discard upcoming disks (excluding current dialog where disks have been selected)
					if [[ -z "${partition[@]}" ]]
					then
						unset DisksSize
						# DiscardDisksTemp=("${Disks[@]}")
						# DiscardDisks=("${DiscardDisksTemp[@]:$a}")
						DiscardDisks=("${Disks[@]}")
						DiscardDisks=("${DiscardDisks[@]:$a}")
						unset DiscardDisksTemp
					elif [[ -n ${partition[@]} ]]
					then
						SelectedPartitions+=("${partition[@]}")
						if [[ "${Disks[-1]}" != "${Disks[$a]}" ]]
						then
							unset DisksSize
							local size=${#Disks[@]}
							size=$((size-1))
							# DiscardDisksTemp=("${Disks[@]}")
							# DiscardDisks=("${DiscardDisksTemp[@]:$a}")
							DiscardDisks=("${Disks[@]}")
							DiscardDisks=("${DiscardDisks[$a]:$size}")
							unset DiscardDisksTemp size
							break
						fi
					fi

					# "discard", "edit" and "select partition" behaviour
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
					# array of selected partitions and Disks to discard
					if [[ -z "${partition[@]}" ]]
					then
						unset DisksSize
						DiscardDisks=("${Disks[$a]}")
					elif [[ -n ${partition[@]} ]]
					then
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

	# conditionals on what to do if the right number of and partitions are not selected
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

	elif [[ -z ${linux_fs_parts[@]} ]]
	then
		dialog --msgbox "No partition with Linux filesystem selected. Please select one from the partitions of the selected ${diskhave[0]} ${m_DisksTemp[*]}" 0 0
		unset diskhave m_DisksTemp SelectedPartitions
		MountViewPartitions Disks

	elif [[ -z ${efi_parts[@]} ]]
	then
		dialog --msgbox "No EFI partition selected. Please select one from the partitions of the selected ${diskhave[0]} ${m_DisksTemp[*]}. (The EFI partition is basically where the kernel and the boot files reside)" 0 0
		unset SelectedPartitions
		MountViewPartitions Disks

	elif [[ ${#linux_fs_parts[@]} -gt 1 ]] && [[ ${#efi_parts[@]} -eq 1 ]]
	then
		dialog --msgbox "Use one Linux filesystem partition. Using ${diskhave[0]} ${m_DisksTemp[*]}" 0 0
		unset diskhave m_DisksTemp SelectedPartitions
		MountViewPartitions Disks

	elif [[ ${#efi_parts[@]} -gt 1 ]] &&  [[ ${#linux_fs_parts[@]} -eq 1 ]]
	then
		dialog --msgbox "Use only one EFI partition (This is basically where the kernel and the boot files reside)" 0 0
		unset SelectedPartitions
		MountViewPartitions Disks

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

	elif [[ ${#efi_parts[@]} -eq 1 ]] && [[ ${#linux_fs_parts[@]} -eq 1 ]] && [[ -z ${linux_swap_parts[@]} ]] && [[ -n ${linux_home_parts[@]} ]]
	then
		dialog --yes-label "Back" --no-label "continue" --yesno "No swap partition selected. Recommended to have a swap partition. Continue without a swap partition or Go Back to the partition mount menu to select a swap partition?" 0 0
		case $? in
			0)
				unset SelectedPartitions
				MountViewPartitions Disks
				;;
			1) ConfirmMounts Disks SelectedPartitions ;;
		esac

	elif [[ ${#efi_parts[@]} -eq 1 ]] && [[ ${#linux_fs_parts[@]} -eq 1 ]] && [[ -z ${linux_home_parts[@]} ]] && [[ -z ${linux_swap_parts[@]} ]]
	then
		dialog --yes-label "Back" --no-label "Continue" --yesno "No swap and linux home partitions selected. Continue without them or go back to the partition selection menu?" 0 0
		case $? in
			0)
				unset SelectedPartitions
				MountViewPartitions Disks
				;;
			1) ConfirmMounts Disks SelectedPartitions ;;
		esac


	elif [[ ${#linux_swap_parts[@]} -ge 1 ]] && [[ ${#efi_parts[@]} -eq 1 ]] && [[ ${#linux_fs_parts[@]} -eq 1 ]] && [[ -z ${linux_home_parts[@]} ]]
	then

		dialog --yes-label "Back" --no-label "continue" --yesno "No linux home or linux user's home partition selected. Continue without one of these partitions or Go Back to the partition mount menu to select a home partition?" 0 0
		case $? in
			0)
				unset SelectedPartitions
				MountViewPartitions Disks
				;;
			1) ConfirmMounts Disks SelectedPartitions ;;
		esac

	elif [[ ${#linux_swap_parts[@]} -ge 1 ]] && [[ ${#efi_parts[@]} -eq 1 ]] && [[ ${#linux_fs_parts[@]} -eq 1 ]] && [[ -n ${linux_home_parts[@]} ]]
	then
		ConfirmMounts Disks SelectedPartitions
	fi
}

###################################################### end of disk editing #################################################




################################################## host configuration ######################################################

# To install a desktop environment or a window manager
Install_UI(){

	# $1 - options in this function's menu

	local pkgs=""
	local ui_type=""
	local wmopts=()
	local deopts=()
	local ui_opts=()
	local xinitrc_string=""

	ui_opts+=("Window Manager")
	ui_opts+=("Just windows, statusbars, dmenus (minimal).No Graphics composition like on Gnome")
	ui_opts+=("Desktop Environment")
	ui_opts+=("Gnome, KDE, cinnamon and stuff like that")

	local UI
	UI=$(dialog --cancel-label "BACK" --default-item "${1}" --menu "UI Menu" 0 0 0 "${ui_opts[@]}" 3>&1 1>&2 2>&3)
	case $? in
		1) ConfHost "Install UI" ;;
		0)
			wmopts+=("i3" "i3")
			wmopts+=("bspwm" "bspwm")
			wmopts+=("awesome" "awesome")
			wmopts+=("xmonad" "xmonad")
			wmopts+=("enlightenment" "enlightenment")

			deopts+=("KDE" "KDE")
			deopts+=("Gnome" "Gnome")
			deopts+=("cinnamon" "cinnamon")
			deopts+=("deepin" "deepin")
			deopts+=("lxde" "lxde")
			deopts+=("lxqt" "lxqt")
			deopts+=("mate" "mate")
			deopts+=("Unity" "Unity")
			deopts+=("xfce4" "xfce4")

			case $UI in
				"Desktop Environment")
					local DE
					DE=$(dialog --no-tags --cancel-label "BACK" --menu "Desktop Environment Menu" 0 0 0 "${deopts[@]}" 3>&1 1>&2 2>&3)
					case $? in
						1) Install_UI "Desktop Environment" ;;
						0) 
							case $DE in
								"KDE")
									pkgs="$(pacman -Sg plasma kde-{applications,system,graphics,network,accessibility} kf{5,5-aids} | awk '{print $2}' | uniq)"
									ui_type="KDE"
									xinitrc_string="startplasma-x11"
									;;
								"Gnome")
									ui_type="Gnome"
									pkgs="gnome gnome-extra"
									xinitrc_string=""
									;;
								"cinnamon")
									ui_type="cinnamon"
									pkgs="$(pacman -Ssq cinnamon)"
									xinitrc_string=""
									;;
								"deepin")
									ui_type="deepin"
									pkgs="deepi{n,n-extra}"
									xinitrc_string=""
									;;
								"lxde")
									ui_type="lxde"
									pkgs="lxd{e,e-gtk3}"
									xinitrc_string=""
									;;
								"lxqt")
									ui_type="lxqt"
									pkgs="lxqt"
									xinitrc_string=""
									;;
								"mate")
									ui_type="mate"
									pkgs="mat{e,e-extra}"
									xinitrc_string="mate-session"
									;;
								"xfce4")
									ui_type="xfce4"
									pkgs="xfce4"
									xinitrc_string="startxfce4"
									;;
							esac
							;;
					esac
					;;
				"Window Manager")
					local WM
					WM=$(dialog --no-tags --cancel-label "BACK" --menu "Window Manager Menu" 0 0 0 "${wmopts[@]}" 3>&1 1>&2 2>&3)

					case $? in
						1) Install_UI "Window Manager" ;;
						0)
							case $WM in
								"i3")
									ui_type="i3"
									pkgs=$(pacman -Ssq i3 | grep -iv 'py\|7\|perl\|sway\|rust')
									xinitrc_string="i3"
									;;
								"bspwm")
									ui_type="bspwm"
									pkgs="bspwm"
									xinitrc_string=""
									;;
								"awesome")
									ui_type="awesome"
									pkgs="awesom{e,e-terminal-fonts} vicious powerline "
									xinitrc_string=""
									;;
								"xmonad")
									ui_type="xmonad"
									pkgs="xmonad xmonad-{contrib,utils}"
									xinitrc_string=""
									;;
								"enlightenment")
									ui_type="enlightenment"
									pkgs="enlightenment ef{l,l-docs}"
									xinitrc_string=""
									;;
							esac
							;;
					esac
					;;
			esac
			dialog --msgbox "$ui_type packages that will be installed:\n$pkgs" 0 0

			# when base is installed and script is running from live disk
			if [[ -d /run/archiso/airootfs ]] && [[ -d /run/archiso/bootmnt ]] && ( mountpoint /run/archiso/airootfs &>/dev/null ) && ( mountpoint /run/archiso/bootmnt &>/dev/null ) && ( mountpoint /mnt &>/dev/null ) && [[ -d /mnt/boot ]] && ( mountpoint /mnt/boot &>/dev/null )
			then
				pacstrap /mnt $pkgs

			# when base is installed and script is running from installed device
			elif ( ( ! mountpoint /mnt &>/dev/null ) || ( [[ ! -d /mnt/boot ]] && ( ! mountpoint /mnt/boot &>/dev/null ) ) ) && ( [[ ! -d /run/archiso/airootfs ]] && [[ ! -d /run/archiso/bootmnt ]] ) && ( ( mountpoint / &>/dev/null ) && ( mountpoint /boot &>/dev/null ) )
			then
				pacman -Syvd $pkgs
			fi
			ConfHost "Install UI"
			;;
	esac

}

SetTz(){
	# $1 - default option
	local regions=()
	local zones=()

	local regions_dir_temp=($(ls -d /usr/share/zoneinfo/* | grep -iv 'right\|posix\|\.[a-zA-Z0-9]*'))
	local regions_temp=($(ls /usr/share/zoneinfo/ | grep -iv 'right\|posix\|\.[a-zA-Z0-9]*'))

	for (( b = 0; b < ${#regions_dir_temp[@]}; b++ ))
	do
		if [[ -d "${regions_dir_temp[$b]}" ]]
		then
			regions+=("${regions_dir_temp[$b]}")
			regions+=("${regions_temp[$b]}")
		fi
	done
	unset regions_temp regions_dir_temp

	local region
	region=$(dialog --cancel-label "Back" --no-tags --menu "select the continent you are in" 0 0 0 "${regions[@]}" 3>&1 1>&2 2>&3)
	case $? in
		1) ConfHost "set timezone" ;;
		0)
			clear
			local zones_temp=()
			zones_temp=($(ls "$region/"))

			for (( b = 0; b < ${#zones_temp[@]}; b++ ))
			do
				if [[ -f "$region/${zones_temp[$b]}" ]] && [[ -r "$region/${zones_temp[$b]}" ]]
				then
					zones+=("$region/${zones_temp[$b]}")
					zones+=("${zones_temp[$b]}")
				fi
			done

			local zone
			zone=$(dialog --no-tags --cancel-label "back" --menu "select the region you are in" 0 0 0 "${zones[@]}" 3>&1 1>&2 2>&3)
			case $? in
				1) SetTz ;;
				0)
						# when base is installed and script is running from live disk
						if [[ -d /run/archiso/airootfs ]] && [[ -d /run/archiso/bootmnt ]] && ( mountpoint /run/archiso/airootfs &>/dev/null ) && ( mountpoint /run/archiso/bootmnt &>/dev/null ) && ( mountpoint /mnt &>/dev/null ) && [[ -d /mnt/boot ]] && ( mountpoint /mnt/boot &>/dev/null )
						then
							ln -sf $zone /mnt/etc/localtime &>/dev/null
							arch-chroot /mnt/ hwclock -wv | GuageMeter "Setting Hardware Clock" 1
							local HWCLOCK_EXIT_CODE=${PIPESTATUS[0]}
							# hwclock -wv | GuageMeter "Setting Hardware Clock" 1
							# HWCLOCK_EXIT_CODE=$?

						# when base is installed and script is running from installed device
						elif ( ( ! mountpoint /mnt &>/dev/null ) || ( [[ ! -d /mnt/boot ]] && ( ! mountpoint /mnt/boot &>/dev/null ) ) ) && ( [[ ! -d /run/archiso/airootfs ]] && [[ ! -d /run/archiso/bootmnt ]] ) && ( ( mountpoint / &>/dev/null ) && ( mountpoint /boot &>/dev/null ) )
						then
							ln -sf $zone /etc/localtime &>/dev/null
							hwclock -wv | GuageMeter "Setting Hardware Clock" 1
							local HWCLOCK_EXIT_CODE=${PIPESTATUS[0]}
						fi
					case $HWCLOCK_EXIT_CODE in
						0) 
							zone="$(echo $zone | sed 's/\// \/ /g' | awk ' { region=(NF-2);print $region"-"$NF }')"
							dialog --msgbox "Hardware Clock and timezone is $zone" 0 0
							;;
						1) dialog --msgbox "timezone or Hardware Clock could not be set" 0 0 ;;
					esac
					;;
			esac
			;;
	esac
}

SetLocale(){

	local LOCALE=()

	# temporary file to store locale.gen info
	cat "/etc/locale.gen" | grep -i '#[a-zA-Z0-9]' | sed 's/#//' > locales.txt

	# locale selection checklist items
	while read txt
	do
		LOCALE+=("$txt")
		LOCALE+=("$txt")
		LOCALE+=(OFF)
	done < locales.txt

	local LocaleDialog
	LocaleDialog=$(dialog --scrollbar --visit-items --extra-button --extra-label "Manually Set Locale" --cancel-label "BACK" --title "Locale Selection Menu" --buildlist "\nUse the space bar to move locale options between the panes and use the tab for moving in between spacess. If no locale is selected then the deafult UTF-8 and ISO-8859 versions of the US english locales will be set \n\n           disabled locales                                          enabled locales" 0 0 0 "${LOCALE[@]}" 3>&1 1>&2 2>&3)
	case $? in
		0)
			unset LOCALE
			echo "${LocaleDialog[@]}" | sed 's/" "/"\n"/g;s/"//g' > locales.txt
			local LocaleFormat

			# when base is installed and script is running from live disk
			if [[ -d /run/archiso/airootfs ]] && [[ -d /run/archiso/bootmnt ]] && ( mountpoint /run/archiso/airootfs &>/dev/null ) && ( mountpoint /run/archiso/bootmnt &>/dev/null ) && ( mountpoint /mnt &>/dev/null ) && [[ -d /mnt/boot ]] && ( mountpoint /mnt/boot &>/dev/null )
			then
				while read txt
				do
					sed -i s/"#$txt"/"$txt"/g /mnt/etc/locale.gen
				done < locales.txt # substituing texts in "locale.gen" with texts in "locales.txt"
				rm -rfv locales.txt &>/dev/null
				LocaleFormat="$(echo -e "\n\n${LocaleDialog[*]}\n" | sed 's/" "/"\n"/g')" # locales text for use in dialog
				arch-chroot /mnt locale-gen | GuageMeter "Generating Locales" 1

			# when base is installed and script is running from installed device
			elif ( ( ! mountpoint /mnt &>/dev/null ) || ( [[ ! -d /mnt/boot ]] && ( ! mountpoint /mnt/boot &>/dev/null ) ) ) && ( [[ ! -d /run/archiso/airootfs ]] && [[ ! -d /run/archiso/bootmnt ]] ) && ( ( mountpoint / &>/dev/null ) && ( mountpoint /boot &>/dev/null ) )
			then
				while read txt
				do
					sed -i s/"#$txt"/"$txt"/g /etc/locale.gen
				done < locales.txt # substituing texts in "locale.gen" with texts in "locales.txt"
				rm -rfv locales.txt &>/dev/null
				LocaleFormat=$(echo -e "\n\n${LocaleDialog[*]}\n" | sed 's/" "/"\n"/g') # locales text for use in dialog
				locale-gen | GuageMeter "Generating Locales" 1
			fi
			dialog --msgbox "Set Locales :$LocaleFormat" 0 0
			unset LocaleFormat
			;;
		1) ConfHost "set Locale *" ;;
		3)
			# when base is installed and script is running from live disk
			if [[ -d /run/archiso/airootfs ]] && [[ -d /run/archiso/bootmnt ]] && ( mountpoint /run/archiso/airootfs &>/dev/null ) && ( mountpoint /run/archiso/bootmnt &>/dev/null ) && ( mountpoint /mnt &>/dev/null ) && [[ -d /mnt/boot ]] && ( mountpoint /mnt/boot &>/dev/null )
			then
				cp -rf /mnt/etc/locale.gen /mnt/etc/locale_copy.gen
				dialog --msgbox "only uncomment the locales you want to use on the machine" 0 0
				vim /mnt/etc/locale.gen
				diff /mnt/etc/locale.gen /mnt/etc/locale_copy.gen
				case $? in
					0) 
						arch-chroot /mnt locale-gen
						local set_localesTemp=($(diff locales.txt /mnt/etc/locale.gen | grep -iv '#' | grep -i '>' | sed 's/> //g;s/ /+/g'))
						local set_locales=()
						for w in ${set_localesTemp[@]}
						do
							set_locales+=("$(echo $w | sed 's/+//g')")
						done
						local locales_text=""
						if [[ ${set_locales[@]} -eq 1 ]]
						then
							locales_text="locale"
						elif [[ ${set_locales[@]} -gt 1 ]]
						then
							locales_text="locales"
						fi
						dialog --msgbox "$locales_text set:\n${set_locales[*]}" 0 0
						;;
					1)
						;;
				esac
				rm -rf /mnt/etc/locale_copy.gen
				
			# when base is installed and script is running from installed device
			elif ( ( ! mountpoint /mnt &>/dev/null ) || ( [[ ! -d /mnt/boot ]] && ( ! mountpoint /mnt/boot &>/dev/null ) ) ) && ( [[ ! -d /run/archiso/airootfs ]] && [[ ! -d /run/archiso/bootmnt ]] ) && ( ( mountpoint / &>/dev/null ) && ( mountpoint /boot &>/dev/null ) )
			then
				dialog --msgbox "only uncomment the locales you want to use on the machine" 0 0
				cp -rf /etc/locale.gen /etc/locale_copy.gen
				vim /etc/locale.gen
				diff /etc/locale.gen /etc/locale_copy.gen
				case $? in
					0)
						locale-gen
						local set_localesTemp=($(diff locales.txt /etc/locale.gen | grep -iv '#' | grep -i '>' | sed 's/> //g;s/ /+/g'))
						local set_locales=()
						for w in ${set_localesTemp[@]}
						do
							set_locales+=("$(echo $w | sed 's/+//g')")
						done
						local locales_text=""
						if [[ ${set_locales[@]} -eq 1 ]]
						then
							locales_text="locale"
						elif [[ ${set_locales[@]} -gt 1 ]]
						then
							locales_text="locales"
						fi
						dialog --msgbox "$locales_text set:\n${set_locales[*]}" 0 0
						;;

					1) dialog --msgbox "no locales have been uncommented. Therefore default en_US.UTF-8 will be used as default locale" ;;
				esac
				rm -rf /etc/locale_copy.gen
			fi
			;;
	esac

}


SetHostName(){
	local hostname="$(dialog --inputbox "Set host name or eave blank to set default name \"arch\"" 0 0 3>&1 1>&2 2>&3)"

	if [[ -z $hostname ]]
	then
		hostname="arch"
	fi

	# when base is installed and script is running from live disk
	if [[ -d /run/archiso/airootfs ]] && [[ -d /run/archiso/bootmnt ]] && ( mountpoint /run/archiso/airootfs &>/dev/null ) && ( mountpoint /run/archiso/bootmnt &>/dev/null ) && ( mountpoint /mnt &>/dev/null ) && [[ -d /mnt/boot ]] && ( mountpoint /mnt/boot &>/dev/null )
	then
		echo "$hostname" > "/mnt/etc/hostname"
		echo -e "127.0.0.1\tlocalhost\n      ::1\tlocalhost" > "/mnt/etc/hosts"

	# when base is installed and script is running from installed device
	elif ( ( ! mountpoint /mnt &>/dev/null ) || ( [[ ! -d /mnt/boot ]] && ( ! mountpoint /mnt/boot &>/dev/null ) ) ) && ( [[ ! -d /run/archiso/airootfs ]] && [[ ! -d /run/archiso/bootmnt ]] ) && ( ( mountpoint / &>/dev/null ) && ( mountpoint /boot &>/dev/null ) )
	then
		echo "$hostname" > "/etc/hostname"
		echo -e "127.0.0.1\tlocalhost\n      ::1\tlocalhost" > "/mnt/etc/hosts"
	fi

	dialog --yes-label "OK" --no-label "Back" --yesno "set \"$hostname\" as hostname. You can change the hostname in the /etc/hostname file (if you are not in live mode i.e.) or if you are in live mode then edit the /mnt/etc/hostname file. To reset hostname press \"Back\"" 0 0
	case $? in
		1) SetHostName ;;
	esac
}

SetPassword(){

	# password needs to be equal or greater than 8 characters

	local username=$1

	local password
	local NewPassword
	NewPassword="$(dialog --passwordbox "you won't see the password characters as they are typed\n\nset password for username $username" 0 0 3>&1 1>&2 2>&3)"
	case $? in
		1) add_users ;;
		0)
			if [[ -z $NewPassword ]]
			then
				dialog --yesno "Accounts without passwords is as good as an inaccessible account (i.e. if the passwordless account is the only non-root account you have created). linux will prompt you for a password regardless of password state on an account/username.\nYou can login into the passwordless account by doing one, select few or all of the following\n1) logging in with an account that contains a password (if you have created one i.e.) and then logging in with the 'passwordless account' from the currently active account\n2) logging in as root and then loggin in with the 'passwordless account'.\n3) going to line 79 of /etc/sudoers and adding '<passwordless account name> ALL=(ALL) NOPASSWD: ALL'\n\nAll the above is as per my experience.\nProceed setting the passwordless account regardless?" 0 0
				case $? in
					# 0) password="$NewPassword" ;;
					1) SetPassword $username ;;
				esac
			elif [[ -n $NewPassword ]]
			then
				if [[ ${#NewPassword} -lt 8 ]] && ( [[ -z $NewPassword ]] || [[ "$NewPassword" == "" ]] )
				then
					dialog --msgbox "password need to be atleast 8 characters long" 0 0
					SetPassword $username
				elif [[ ${#NewPassword} -ge 8 ]]
				then
					local ConfirmPassword
					ConfirmPassword="$(dialog --passwordbox "Confirm password for username $username" 0 0 3>&1 1>&2 2>&3)"
					if [[ "$ConfirmPassword" == "$NewPassword" ]]
					then

						# when base is installed and script is running from live disk
						if [[ -d /run/archiso/airootfs ]] && [[ -d /run/archiso/bootmnt ]] && ( mountpoint /run/archiso/airootfs &>/dev/null ) && ( mountpoint /run/archiso/bootmnt &>/dev/null ) && ( mountpoint /mnt &>/dev/null ) && [[ -d /mnt/boot ]] && ( mountpoint /mnt/boot &>/dev/null )
						then
							printf "$NewPassword\n$NewPassword\n" | arch-chroot /mnt passwd $username &>/dev/null
							SETPASSWD_EXIT_CODE=${PIPESTATUS[1]}

						# when base is installed and script is running from installed device
						elif ( ( ! mountpoint /mnt &>/dev/null ) || ( [[ ! -d /mnt/boot ]] && ( ! mountpoint /mnt/boot &>/dev/null ) ) ) && ( [[ ! -d /run/archiso/airootfs ]] && [[ ! -d /run/archiso/bootmnt ]] ) && ( ( mountpoint / &>/dev/null ) && ( mountpoint /boot &>/dev/null ) )
						then
							printf "$NewPassword\n$NewPassword\n" | passwd $username &>/dev/null
							SETPASSWD_EXIT_CODE=${PIPESTATUS[1]}
						fi
						case $SETPASSWD_EXIT_CODE in
							0) dialog --msgbox "password for $username is set" 0 0 ;;
							1)
								dialog --msgbox "password for $username is weak" 0 0
								SetPassword $username
								;;
							10)
								dialog --msgbox "$username does not exist" 0 0
								local usersTemp=($(cat /etc/passwd | sed 's/:/ : /g' | grep -iG '[1-9][0-9][0-9][0-9]\d*' | grep -iv nobody | awk '{ print $1 }'))
								local users=()
								for p in ${usersTemp[@]}
								do
									users+=("$p" "")
								done
								unset usersTemp
								username=$(dialog --no-tags --menu "available users" 0 0 0 ${users[@]} 3>&1 1>&2 2>&3)
								SetPassword $username
								unset username users
								;;
						esac
					elif [[ "$ConfirmPassword" != "$NewPassword" ]]
					then
						dialog --msgbox "passwords do not match" 0 0
						SetPassword $username
					fi
				fi
			fi
			;;
	esac
}

add_users(){
	local username
	username="$(dialog --inputbox "Username" 0 0 3>&1 1>&2 2>&3)"
	case $? in
		1) ConfHost "add users **" ;;
		0)
			if [[ -z $username ]]
			then
				dialog --msgbox "username cannot be empty" 0 0
				add_users
			fi

			local USERADD_EXIT_CODE
			# when base is installed and script is running from live disk
			if [[ -d /run/archiso/airootfs ]] && [[ -d /run/archiso/bootmnt ]] && ( mountpoint /run/archiso/airootfs &>/dev/null ) && ( mountpoint /run/archiso/bootmnt &>/dev/null ) && ( mountpoint /mnt &>/dev/null ) && [[ -d /mnt/boot ]] && ( mountpoint /mnt/boot &>/dev/null )
			then
				arch-chroot /mnt useradd -m $username -g users -G power,wheel,storage &>/dev/null
				USERADD_EXIT_CODE=$?

			# when base is installed and script is running from installed device
			elif ( ( ! mountpoint /mnt &>/dev/null ) || ( [[ ! -d /mnt/boot ]] && ( ! mountpoint /mnt/boot &>/dev/null ) ) ) && ( [[ ! -d /run/archiso/airootfs ]] && [[ ! -d /run/archiso/bootmnt ]] ) && ( ( mountpoint &>/dev/null / ) && ( mountpoint /boot &>/dev/null ) )
			then
				useradd -m $username -g users -G power,wheel,storage &>/dev/null
				USERADD_EXIT_CODE=$?
			fi

			case $USERADD_EXIT_CODE in
				0) 
					dialog --msgbox "Created user $username" 0 0
					SetPassword $username
					;;
				9)
					dialog --yesno "User $username already exists. Reset password?" 0 0
					case $? in
						0) SetPassword $username ;;
					esac
					;;
			esac
			;;
	esac
}

BashPromptPreview(){
	# drops to a subshell using the set rc file
	clear
	bash_prompt="$1"
	curdir="$PWD"
	bash --rcfile "$curdir/shell rc/bash/$bash_prompt"
}

SetPrompt(){

	bashrc_file="$1"
	local folder_path=""

	# when base is installed and script is running from live disk
	if [[ -d /run/archiso/airootfs ]] && [[ -d /run/archiso/bootmnt ]] && ( mountpoint /run/archiso/airootfs &>/dev/null ) && ( mountpoint /run/archiso/bootmnt &>/dev/null ) && ( mountpoint /mnt &>/dev/null ) && [[ -d /mnt/boot ]] && ( mountpoint /mnt/boot &>/dev/null )
	then
		folder_path="/mnt/home"

	# when base is installed and script is running from installed device
	elif ( ( ! mountpoint /mnt &>/dev/null ) || ( [[ ! -d /mnt/boot ]] && ( ! mountpoint /mnt/boot &>/dev/null ) ) ) && ( [[ ! -d /run/archiso/airootfs ]] && [[ ! -d /run/archiso/bootmnt ]] ) && ( ( mountpoint / &>/dev/null ) && ( mountpoint /boot &>/dev/null ) )
	then
		folder_path="/home"
	fi


	local Users=($(grep [1-9][0-9][0-9][0-9] /mnt/etc/passwd | grep -iv nobody | sed 's/\:/ \: /g' | awk '{print $1}'))

	# set bashrc file for only one existing user
	if [[ ${#Users[@]} -eq 1 ]]
	then
		cp shell\ rc/bash/"$1" "$folder_path/${Users[0]}/.bashrc" &>/dev/null
		dialog --msgbox "set $1 as the bash prompt for user ${Users[0]}" 0 0

	# set bashrc file to selected users
	elif [[ ${#Users[@]} -gt 1 ]]
	then
		dialog --yes-label "OK" --no-label "Skip" --yesno "set  for all users, one user or selected user?" 0 0
		case $? in
			0)
				local UsersTemp=()
				for i in ${Users[@]}
				do
					UsersTemp+=("$i" "" 0)
				done

				local SelectedUsers="$(dialog --no-tags --checklist "Select user(s) that will use this $bashrc_file bashrc file" 0 0 0 "${UsersTemp[@]}" 3>&1 1>&2 2>&3)"

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
					cp shell\ rc/bash/"$bashrc_file" "$folder_path/$User/.bashrc" &>/dev/null
				done | GuageMeter "Setting $bashrc_file for $userText ${SelectedUsersTemp[@]}"
				dialog --msgbox "Set $bashrc_file for $userText ${SelectedUsersTemp[@]}" 0 0
				unset SelectedUsers SelectedUsersTemp UsersTemp userText
				;;
			1) dialog --msgbox "default bashrc will be used" 0 0 ;;
		esac
	fi
	unset Users folder_path
}

SetBashPrompt(){
	# $1 - "menu option item"

	local bashrc_opts=("default" "it's the same as you see on the live iso")
	bashrc_opts+=("modded parrot" "my personalized version of the parrot OS bash prompt")
	bashrc_opts+=("parrot" "bash prompt taken from parrot OS")
	bashrc_opts+=("pop OS" "pop OS bash prompt")
	local Users=($(grep [1-9][0-9][0-9][0-9] /etc/passwd | grep -iv nobody | sed 's/\:/ \: /g' | awk '{print $1}'))

	$1="${bashrc_opts[0]}"

	local bashrc
	bashrc=$(dialog --ok-label "set bashrc" --default-item "$1" --extra-button --extra-label "preview" --cancel-label "back" --menu "bashrc selection menu\n\nselected menuitem will be saved as \".bashrc\" in the home directory. (Preveiew is best seen when a GUI terminal emulator is installed)" 0 0 0 "${bashrc_opts[@]}" 3>&1 1>&2 2>&3)

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

RemoveUsers(){

	local AvailableUsersTempArgs=$1[@]
	local AvailableUsersTemp=("${!AvailableUsersTempArgs}")
	unset AvailableUsersTempArgs

	local AvailableUsers=()
	local DeletedUsers=()
	local UsersFailedToBeDeleted=()

	if [[ ${#AvailableUsersTemp[@]} -eq 1 ]]
	then
		dialog --yesno "${AvailableUsersTemp[0]} is the only available user. Delete regardless?" 0 0
		case $? in
			0)
				# when base is installed and script is running from live disk
				if [[ -d /run/archiso/airootfs ]] && [[ -d /run/archiso/bootmnt ]] && ( mountpoint /run/archiso/airootfs &>/dev/null ) && ( mountpoint /run/archiso/bootmnt &>/dev/null ) && ( mountpoint /mnt &>/dev/null ) && [[ -d /mnt/boot ]] && ( mountpoint /mnt/boot &>/dev/null )
				then
					arch-chroot /mnt userdel -rf ${AvailableUsersTemp[0]} &>/dev/null

				# when base is installed and script is running from installed device
				elif ( ( ! mountpoint /mnt &>/dev/null ) || ( [[ ! -d /mnt/boot ]] && ( ! mountpoint /mnt/boot &>/dev/null ) ) ) && ( [[ ! -d /run/archiso/airootfs ]] && [[ ! -d /run/archiso/bootmnt ]] ) && ( ( mountpoint / &>/dev/null ) && ( mountpoint /boot &>/dev/null ) )
				then
					userdel -rf ${AvailableUsersTemp[0]} &>/dev/null
					case $? in
						0) dialog --msgbox "Deleted user ${AvailableUsersTemp[0]}" 0 0 ;;
						1) dialog --msgbox "Failed to delete user ${AvailableUsersTemp[0]}" 0 0 ;;
					esac
				fi
				unset AvailableUsersTemp
				;;
		esac
	elif [[ ${#AvailableUsersTemp[@]} -gt 1 ]]
	then

		local AvailableUsers=()
		for y in ${AvailableUsersTemp[@]}
		do
			AvailableUsers+=("$y")
			AvailableUsers+=("$y")
			AvailableUsers+=(0)
		done

		local UsersToDelete=()
		UsersToDelete=($(dialog --no-tags --checklist "Available Users" 0 0 0 "${AvailableUsers[@]}" 3>&1 1>&2 2>&3))
		# when base is installed and script is running from live disk
		if [[ -d /run/archiso/airootfs ]] && [[ -d /run/archiso/bootmnt ]] && ( mountpoint /run/archiso/airootfs &>/dev/null ) && ( mountpoint /run/archiso/bootmnt &>/dev/null ) && ( mountpoint /mnt &>/dev/null ) && [[ -d /mnt/boot ]] && ( mountpoint /mnt/boot &>/dev/null )
		then
			for n in ${UsersToDelete[@]}
			do
				arch-chroot /mnt userdel -rf $n &>/dev/null
				case $? in
					0) DeletedUsers+=("$n") ;;
					1) UsersFailedToBeDeleted+=("$n") ;;
				esac
			done

		# when base is installed and script is running from installed device
		elif ( ( ! mountpoint /mnt &>/dev/null ) || ( [[ ! -d /mnt/boot ]] && ( ! mountpoint /mnt/boot &>/dev/null ) ) ) && ( [[ ! -d /run/archiso/airootfs ]] && [[ ! -d /run/archiso/bootmnt ]] ) && ( ( mountpoint / &>/dev/null ) && ( mountpoint /boot &>/dev/null ) )
		then
			for n in ${UsersToDelete[@]}
			do
				userdel -rf $n &>/dev/null
				case $? in
					0) DeletedUsers+=("$n") ;;
					1) UsersFailedToBeDeleted+=("$n") ;;
				esac
			done
		fi

		local userDeletedText=""
		if [[ -n ${DeletedUsers[@]} ]] && [[ -z ${UsersFailedToBeDeleted[@]} ]]
		then
			local DeletedUsersTempTxt=("${DeletedUsers[*]}")
			DeletedUsersTempTxt=("$(TempArrayWithAmpersand DeletedUsersTempTxt)")
			userDeletedText="Deleted ${DeletedUsersTempTxt[*]}"
			unset DeletedUsersTempTxt
		elif [[ -z ${DeletedUsers[@]} ]] && [[ -n ${UsersFailedToBeDeleted[@]} ]]
		then
			userDeletedText="Failed to delete all users"
		elif [[ -z ${DeletedUsers[@]} ]] && [[ -z ${UsersFailedToBeDeleted[@]} ]]
		then
			local DeletedUsersTempTxt=("${DeletedUsers[*]}")
			DeletedUsersTempTxt=("$(TempArrayWithAmpersand DeletedUsersTempTxt)")

			local UsersFailedToBeDeletedTempTxt=("${UsersFailedToBeDeleted[*]}")
			UsersFailedToBeDeletedTempTxt=("$(TempArrayWithAmpersand UsersFailedToBeDeletedTempTxt)")
			
			userDeletedText="Deleted ${DeletedUsersTempTxt[*]} ${UsersFailedToBeDeletedTempTxt[*]}"

			unset DeletedUsersTempTxt UsersFailedToBeDeletedTempTxt
		fi
		dialog --msgbox "Deleted $userDeletedText " 0 0
		unset UsersToDelete userDeletedText DeletedUsers UsersFailedToBeDeleted
	fi
}

SetRootPassword(){
	local RootPassword
	RootPassword=$(dialog --no-cancel --passwordbox "Enter root password. If no root password is provided then root password will be set to '0n3 Punch M@n'" 0 0 3>&1 1>&2 2>&3)
	if [[ -z $RootPassword ]]
	then
		# when base is installed and script is running from live disk
		if [[ -d /run/archiso/airootfs ]] && [[ -d /run/archiso/bootmnt ]] && ( mountpoint /run/archiso/airootfs &>/dev/null ) && ( mountpoint /run/archiso/bootmnt &>/dev/null ) && ( mountpoint /mnt &>/dev/null ) && [[ -d /mnt/boot ]] && ( mountpoint /mnt/boot &>/dev/null )
		then
			printf "0n3 Punch M@n\n0n3 Punch M@n" | arch-chroot /mnt passwd &>/dev/null

		# when base is installed and script is running from installed device
		elif ( ( ! mountpoint /mnt &>/dev/null ) || ( [[ ! -d /mnt/boot ]] && ( ! mountpoint /mnt/boot &>/dev/null ) ) ) && ( [[ ! -d /run/archiso/airootfs ]] && [[ ! -d /run/archiso/bootmnt ]] ) && ( ( mountpoint / &>/dev/null ) && ( mountpoint /boot &>/dev/null ) )
		then
			printf "0n3 Punch M@n\n0n3 Punch M@n" | passwd &>/dev/null
		fi
		dialog --msgbox "default root password '0n3 Punch M@n' is set " 0 0
	elif [[ -n $RootPassword ]]
	then
		local ConirmRootPassword
		ConirmRootPassword=$(dialog --passwordbox "confirm root password" 0 0 3>&1 1>&2 2>&3)
		if [[ "$RootPassword" != "$ConirmRootPassword" ]]
		then
			dialog --msgbox "root password does not match" 0 0
			SetRootPassword
		elif [[ "$RootPassword" == "$ConirmRootPassword" ]]
		then
			# when base is installed and script is running from live disk
			if [[ -d /run/archiso/airootfs ]] && [[ -d /run/archiso/bootmnt ]] && ( mountpoint /run/archiso/airootfs &>/dev/null ) && ( mountpoint /run/archiso/bootmnt &>/dev/null ) && ( mountpoint /mnt &>/dev/null ) && [[ -d /mnt/boot ]] && ( mountpoint /mnt/boot &>/dev/null )
			then
				printf "$RootPassword\n$RootPassword" | arch-chroot /mnt passwd &>/dev/null
				SETROOTPASSWORD_EXIT_CODE=${PIPESTATUS[1]}

			# when base is installed and script is running from installed device
			elif ( ( ! mountpoint /mnt &>/dev/null ) || ( [[ ! -d /mnt/boot ]] && ( ! mountpoint /mnt/boot &>/dev/null ) ) ) && ( [[ ! -d /run/archiso/airootfs ]] && [[ ! -d /run/archiso/bootmnt ]] ) && ( ( mountpoint / &>/dev/null ) && ( mountpoint /boot &>/dev/null ) )
			then
				printf "$RootPassword\n$RootPassword" | passwd &>/dev/null
				SETROOTPASSWORD_EXIT_CODE=${PIPESTATUS[1]}
			fi

			case $SETROOTPASSWORD_EXIT_CODE in
				0) dialog --msgbox "root password is set" 0 0 ;;
				10)
					dialog --msgbox "root password entered is weak and is not set" 0 0
					SetRootPassword
					;;
			esac
		fi
	fi
}

ConfHost(){
	# $1 - menu option item
	local default_menu_opt=$1

	local usersTemp=""

	# host config options for use in dialog
	local HostOpt=("set hostname *" "set your computer name")
	HostOpt+=("set Locale *" "set your computer language")
	HostOpt+=("set timezone" "configure which timezone you are in")
	HostOpt+=("add users **" "add users")
	HostOpt+=("root password **" "set root password")

	# when base is installed and script is running from live disk
	if ( ( ! mountpoint /mnt &>/dev/null ) || ( [[ ! -d /mnt/boot ]] && ( ! mountpoint /mnt/boot &>/dev/null ) ) ) && ( [[ ! -d /run/archiso/airootfs ]] && [[ ! -d /run/archiso/bootmnt ]] ) && ( ( mountpoint / &>/dev/null ) && ( mountpoint /boot &>/dev/null ) )
	then
		HostOpt+=("Set Bash Prompt" "File that's used to tell how the terminal prompt should look like")
		usersTemp=($(cat /etc/passwd | sed 's/:/ : /g' | grep -iG '[1-9][0-9][0-9][0-9]\d*' | grep -iv nobody | awk '{ print $1 }'))

	# when base is installed and script is running from installed device
	elif [[ -d /run/archiso/airootfs ]] && [[ -d /run/archiso/bootmnt ]] && ( mountpoint /run/archiso/airootfs &>/dev/null ) && ( mountpoint /run/archiso/bootmnt &>/dev/null ) && ( mountpoint /mnt &>/dev/null ) && [[ -d /mnt/boot ]] && ( mountpoint /mnt/boot &>/dev/null )
	then
		HostOpt+=("Install UI" "Install Desktop Environment or Window Manager")
		usersTemp=($(cat /mnt/etc/passwd | sed 's/:/ : /g' | grep -iG '[1-9][0-9][0-9][0-9]\d*' | grep -iv nobody | awk '{ print $1 }'))
	fi

	# local "${HostOpt[0]}"=$1
	if [[ -n ${usersTemp[@]} ]]
	then
		if [[ ${#usersTemp[@]} -eq 1 ]]
		then
			HostOpt+=("Remove User" "Delete existing user \"${usersTemp[0]}\"")
		elif [[ ${#usersTemp[@]} -gt 1 ]]
		then
			HostOpt+=("Remove Users" "Delete existing users")
		fi
	fi

	# default_menu_opt="${HostOpt[0]}"
	local opt
	opt=$(dialog --cancel-label "BACK" --default-item "$default_menu_opt" --menu "Host Configuration Menu" 0 0 0 "${HostOpt[@]}" 3>&1 1>&2 2>&3)
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
				"root password **")
					dialog --msgbox "you won't see the characters as you type" 0 0
					SetRootPassword
					ConfHost "set root password"
					;;
				"Install UI")
					Install_UI "Window Manager"
					ConfHost "Install UI"
					;;
				"Set Bash Prompt")
					SetBashPrompt
					ConfHost "Set Bash Prompt"
					;;
				"Remove Users"|"Remove User")
					RemoveUsers usersTemp
					ConfHost "root password *"
					;;
			esac
			;;
		1) MainMenu "Configure Host +" ;;
	esac
}
############################################## end of host configuration ###################################################


InstallArch(){

	# check if linux partition is mounted
	if ( [[ -d /run/archiso/airootfs ]] && [[ -d /run/archiso/bootmnt ]] && ( mountpoint /run/archiso/airootfs &>/dev/null ) && ( mountpoint /run/archiso/bootmnt &>/dev/null ) && ( ! mountpoint /mnt &>/dev/null ) && [[ ! -d /mnt/boot ]] && ( ! mountpoint /mnt/boot &>/dev/null ) )
	then
		dialog --msgbox "root partition not mounted/set" 0 0
		MainMenu "Install Arch *"

	elif ( [[ -d /run/archiso/airootfs ]] && [[ -d /run/archiso/bootmnt ]] && ( mountpoint /run/archiso/airootfs &>/dev/null ) && ( mountpoint /run/archiso/bootmnt &>/dev/null ) && ( mountpoint /mnt &>/dev/null ) && [[ -d /mnt/boot ]] && ( mountpoint /mnt/boot &>/dev/null ) )
	then
		local packages=()

		# variable holding regex form of packages
		packages_temp=(base base-devel linu{x,x-{docs,headers}} grub efi{var,bootmgr} git wget lynx dkms broadcom-wl-dkms xf86-input-{libinput,synaptics} xf86-video-fbdev vim sudo)

		# expanding the regex package variable for display in dialog
		for i in "${packages_temp[@]}"
		do
			packages+=("$i")
		done
		unset packages_temp

		# installing system
		pacman-key --init
		pacstrap /mnt "${packages[@]}"
		case $? in
			0)
				# installing grub 
				dialog --msgbox "Installed Arch Base system successfully" 0 0
				local bootloaderid
				bootloaderid="$(dialog --inputbox "Bootloader ID - Input Any Text. Leave Blank for default ID \"ARCH_LINUX_GRUB\"" 0 0 3>&1 1>&2 2>&3)"
				if [[ -z $bootloaderid ]] || [[ "$bootloaderid" == "" ]] || [[ "$bootloaderid" =~ " " ]]
				then
					bootloaderid="ARCH_LINUX_GRUB"
				fi

				local mountptdev=""
				local grub_disk_array=($(lsblk -dnlo name | grep -iv 'loop\|sr[0-9]\|fd[0-9]'))
				for b in ${grub_disk_array[@]}
				do
					local grub_part_array=($(lsblk /dev/$b -nlo name))
					for h in ${grub_part_array[@]}
					do
						local mountpt=$(lsblk /dev/$h -nlo mountpoint)
						if [[ "$mountpt" == "/mnt/boot" ]]
						then
							mountptdev="$b"
							break
						fi
						unset mountpt
					done
					if [[ -n $mountptdev ]] || [[ "$mountptdev" != "" ]] || [[ ! "$mountptdev" =~ " " ]]
					then
						break
					fi
				done

				local bootdisktype=$(lsblk "/dev/$mountptdev" -dnlo tran,rm)
				local GRUB_INSTALL_EXIT_CODE

				# check if grub install device is removable usb
				if [[ $bootdisktype == "usb 1" ]]
				then
					grub-install -v --boot-directory="/mnt/boot" --bootloader-id "$bootloaderid" --efi-directory="/mnt/boot" --recheck --removable --target x86_efi-efi | GuageMeter "Installing Grub to USB drive $mountptdev" 1
					GRUB_INSTALL_EXIT_CODE=$?

				# check if grub install device is internal drive
				elif [[ $bootdisktype == "sata 0" ]] || [[ $bootdisktype == "ata 0" ]]
				then
					grub-install -v --boot-directory="/mnt/boot" --bootloader-id "$bootloaderid" --efi-directory="/mnt/boot" --recheck --target x86_efi-efi | GuageMeter "Installing Grub to internal disk" 1
					GRUB_INSTALL_EXIT_CODE=$?
				fi
				unset bootdisktype mountptdev

				# create an fstab
				case $GRUB_INSTALL_EXIT_CODE in
					0)
						dialog --msgbox "Installed Grub successfully" 0 0
						if [[ -f "/mnt/etc/fstab" ]] || [[ -d "/mnt/etc/" ]]
						then
							genfstab -U "/mnt" > "/mnt/etc/fstab"
							case $? in
								0) dialog --msgbox "Created fstab entry. you can generate the fstab of your disk by executing \"genfstab -U /mnt > /mnt/etc/fstab\" (if anything went wrong with the fstab entry i.e.)" 0 0 ;;
								*) dialog --msgbox "Failed to create fstab entry" 0 0 ;;
							esac
						elif [[ ! -f "/mnt/etc/fstab" ]]
						then
							if [[ ! -d "/mnt/etc/" ]]
							then
								dialog --msgbox "Failed to install Arch Base system. Exiting the Installer" 0 0
							elif [[ -d "/mnt/etc/" ]]
							then
								dialog --msgbox "Failed to create fstab entry. you can generate the fstab of your disk by executing \"genfstab -U /mnt > /mnt/etc/fstab\" (if anything went wrong with the fstab entry i.e.)" 0 0
							fi
						fi
						MainMenu "Install Arch *"
						;;
					1) dialog --msgbox "could not install grub-bootloader. you execute can \'grub-install --help | less\' on one tty and run \'grub-install <options>\' on another tty. \n\nDO NOT USE THE \'--force\' option.You can open tty's by pressing ctrl+alt+<F1>-<F6> with each function key corresponding to their tty id\n\n Go back to the Main Menu or exit to the tty?" ;;
				esac
				;;
			*)
				if [[ -f "/mnt/etc/fstab" ]] || [[ -d "/mnt/etc/" ]]
				then
					genfstab -U "/mnt" > "/mnt/etc/fstab"
					case $? in
						0) dialog --msgbox "Failed to install Arch Base system but created fstab entry. You can try creating the fstab manuall by executing \"genfstab /mnt/etc/fstab\"Exiting the Installer" 0 0 ;;
						*) dialog --msgbox "Failed to install Arch Base system. Exiting the Installer" 0 0 ;;
					esac
				elif ( [[ ! -d /mnt ]] || ( ! mountpoint /mnt &>/dev/null ) ) || ( [[ ! -f "/mnt/etc/fstab" ]] && [[ ! -d "/mnt/etc/" ]] )
				then
					dialog --msgbox "Failed to install Arch Base system. Exiting the Installer" 0 0
				fi
				exit
				;;
		esac
		unset packages

		# variable to hold cpu info
		cpu_vendor=$(cat /proc/cpuinfo | grep vendor | uniq | awk '{print $3}')

		# create variables holding regex packages, expand them for dispalying in dialog
		local intel_gpu=()
		local intel_gpu_temp=(libva-intel-driver lib32-{libva-intel-driver,vulkan-intel} vulkan-intel intel-graphics-compiler)
		for i in ${intel_gpu_temp[@]}
		do
			intel_gpu+=("$i")
		done
		unset intel_gpu_temp


		# create variables holding regex packages, expand them for dispalying in dialog
		local nvidia_gpu=()
		local nvidia_gpu_temp=(ffnvcodec-headers libvdpau opencl-nvidia xf86-video-nouveau lib32-{libvdpau,nvidia-utils,opencl-nvidia} nvidia-{dkms,lts,prime,settings,utils})
		for i in ${nvidia_gpu_temp[@]}
		do
			nvidia_gpu+=("$i")
		done
		unset nvidia_gpu_temp


		local packages=()
		# array of packages based on the cpu
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
			packages+=("intel-mkl")
			packages+=("intel-undervolt")
			packages+=("throttled")
			packages+=("xf86-video-intel")
			for r in ${intel_gpu[@]}
			do
				packages+=("$r")
			done
			unset intel_gpu
		fi

		# terminal text editors array for use in dialog
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
					packages+=("${editors[@]}")
					unset editors
				fi
				;;
			1)
				unset terminaleditorslist editors
				MainMenu "Install Arch *"
				;;
			3)
				:
				unset terminaleditorslist
				break
				;;
		esac

		dialog --msgbox "Extra packages that will be installed:\n${packages[*]}" 0 0

		pacstrap /mnt "${packages[@]}"
		case $? in
			0) dialog --msgbox "Extra Linux packages have been installed packages" 0 0;;
			*) dialog --msgbox "failed to install Extra Linux packages" 0 0;;
		esac
	fi
}

Repo_Enable(){
	# line number where multilib is commented
	local multilib_linenum=$(grep -ni "multilib\]" /etc/pacman.conf | sed 's/:/ /g' | awk '{ print $1 }')

	# increment multilib line number to uncomment the "Include" line 
	local multilib_include_linenum=$((multilib_linenum+1))

	# line number where Include is commented
	local multilib_line=$(grep -ni "multilib\]" /etc/pacman.conf | sed 's/:/ /g' | awk '{ print $2 }')

	# line where Include is commented
	local multilib_include_line=$(cat -n /etc/pacman.conf | grep -i "$multilib_include_linenum" | sed 's/^\s*[0-9]*//g;s/^\s*Include.*/Include/g')

	# compare the values holding the text in the "include line number" and the "multilib line number"
	if [[ "$multilib_include_line" != "Inlclude*" ]] && [[ "$multilib_line" != "[multilib]" ]]
	then
		dialog --yesno "enable \"multilib\" repo for packages with support for multiple architectures?" 5 80
		case $? in
			0)
				# uncomment the multilib lines and it's dependednt lines
				local linenumber=$(grep -ni "\[multilib\]" /etc/pacman.conf | sed 's/:/ /g' | awk '{ print $1 }')
				sed -i "${linenumber}s/\#\[multilib/\[multilib/g" /etc/pacman.conf
				linenumber=$((linenumber+1))
				sed -i "${linenumber}s/\#Include/Include/g" /etc/pacman.conf
				dialog --msgbox "\"multilib\" repo has been enabled. you can add, remove, disable or enable repos by editing the \"/etc/pacman.conf\" file" 0 0
				pacman -Sy
				;;
			1)
				dialog --no-label "exit" --yes-label "continue installation" --yesno "multilib repo not enabled. To enable it restart the script or uncomment lines #[multilib]\n#Include=/etc/pacman.d/mirrorlist\n in file \"/etc/pacman.conf\"" 6 63
				case $? in
					1) exit ;;
				esac
		esac
	fi
}

MainMenu(){

	# $1 - menu option item

	local DIALOG_CHECK_EXIT_CODE

	# installed base but on live || not installed base but on live
	if [[ -d /run/archiso/airootfs ]] && [[ -d /run/archiso/bootmnt ]] && ( mountpoint /run/archiso/airootfs &>/dev/null ) && ( mountpoint /run/archiso/bootmnt &>/dev/null ) && ( mountpoint /mnt &>/dev/null ) && [[ -d /mnt/boot ]] && ( mountpoint /mnt/boot &>/dev/null ) || ( [[ -d /run/archiso/airootfs ]] && [[ -d /run/archiso/bootmnt ]] && ( mountpoint /run/archiso/airootfs &>/dev/null ) && ( mountpoint /run/archiso/bootmnt &>/dev/null ) && ( ! mountpoint /mnt &>/dev/null ) && [[ ! -d /mnt/boot ]] )
	then
		# ls /usr/bin/dialog &>/dev/null
		which dialog &>/dev/null
		DIALOG_CHECK_EXIT_CODE=$?

	# installed & running base
	elif ( ( ! mountpoint /mnt &>/dev/null ) || ( [[ ! -d /mnt/boot ]] && ( ! mountpoint /mnt/boot &>/dev/null ) ) ) && ( [[ ! -d /run/archiso/airootfs ]] && [[ ! -d /run/archiso/bootmnt ]] ) && ( ( mountpoint / &>/dev/null ) && ( mountpoint /boot &>/dev/null ) )
	then
		local uid=$(id -u)
		# pacman -Qs dialog &>/dev/null
		which dialog &>/dev/null
		DIALOG_CHECK_EXIT_CODE=$?
		case $DIALOG_CHECK_EXIT_CODE in
			0)
				if [[ $uid -ne 0 ]]
				then
					unset uid
					dialog --msgbox "please run this script as root to configure this system. Exiting script" 0 0
					clear
					reset
					exit
				fi
				;;
			1)
				if [[ $uid -ne 0 ]]
				then
					unset uid
					echo "\E[1m\t\t\t\t\t\t\t\tplease run this script as root to configure this system. Exiting script\E[m"
					clear
					reset
					exit
				fi
		esac
	fi

	case $DIALOG_CHECK_EXIT_CODE in
		1|2)
			clear
			echo -e "dialog not installed.\n"
			read -p "press any key to install the git provided dialog package " -s -n1
			clear
			pacman -Uvd --noconfirm "$(ls dialog*.pkg.tar.zst)"
			case $? in
				0) dialog --msgbox "installed dialog" 0 0 ;;
				1)
					clear
					echo -e "\n\ndialog could not be installed.\n\nPlease install provided dialog packages by typing \"pacman -U <package name>\" with or without the \"-vd --noconfirm\" arguments ('-v' -> verbose '-d' -> debug '--noconfirm' -> auto inputs \"yes to every question thrown by the package manager\").\n\ncurrent directory: $(pwd)\npackages in this directory:\n\n$(ls *.pkg*).\n\n\nexiting...\n\n"
					exit
					;;
			esac
			;;
	esac
	unset DIALOG_CHECK_EXIT_CODE

	local menuopt=()
	local menuitem
	local MenuItemText
	local MenuItemTitle

	# installed base but on live || not installed base but on live
	if ( [[ -d /run/archiso/airootfs ]] && [[ -d /run/archiso/bootmnt ]] && ( mountpoint /run/archiso/airootfs &>/dev/null ) && ( mountpoint /run/archiso/bootmnt &>/dev/null ) && ( mountpoint /mnt &>/dev/null ) && [[ -d /mnt/boot ]] && ( mountpoint /mnt/boot &>/dev/null ) ) || ( [[ -d /run/archiso/airootfs ]] && [[ -d /run/archiso/bootmnt ]] && ( mountpoint /run/archiso/airootfs &>/dev/null ) && ( mountpoint /run/archiso/bootmnt &>/dev/null ) && ( ! mountpoint /mnt &>/dev/null ) && [[ ! -d /mnt/boot ]] )
	then
		MenuItemTitle="Install Menu"
		MenuItemText="To install arch all options followed by\n  i) '**' are priority 1\n ii) '*'are priority 2\niii) '+' are priority 3 - optional during installation. you can run the script from an\n                          installed drive to configure the host the script will only have\n                          \"host configuration\" options.\n\nThe rest are optional"
		menuopt=("Partition Disk **" "format/Partition/select Hard Disks and mount partitions")
		menuopt+=("Configure Network **" "Check connectivity and connect to a network")
		menuopt+=("Install Arch *" "Install the base system")
		menuopt+=("Configure Host +" "Personalize the machine by setting Hostname, adding users etc.")

	# installed & running base
	elif ( ( ! mountpoint /mnt &>/dev/null ) || ( [[ ! -d /mnt/boot ]] && ( ! mountpoint /mnt/boot &>/dev/null ) ) ) && ( [[ ! -d /run/archiso/airootfs ]] && [[ ! -d /run/archiso/bootmnt ]] ) && ( ( mountpoint / &>/dev/null ) && ( mountpoint /boot &>/dev/null ) )
	then
		MenuItemTitle="Host Configuration Menu"
		menuopt=("Configure Network" "Check connectivity and connect to a network")
		menuopt+=("Configure Host" "Personalize the machine by setting Hostname, adding users etc.")
		MenuItemText=""
	fi
	menuopt+=("Reboot" "Reboot the machine")

	menuitem=$(dialog --no-mouse --default-item "${1}" --cancel-label "Exit" --title "$MenuItemTitle" --menu "$MenuItemText" 0 0 0 "${menuopt[@]}" 3>&1 1>&2 2>&3)
	case $? in
		0)
			case $menuitem in
				"Partition Disk **")
					PartitionDisk
					MainMenu "Partition Disk **"
					;;
				"Configure Network **"|"Configure Network")
					ConfNet
					MainMenu "Configure Network **"
					;;

				"Install Arch *")
					if ( [[ -d /run/archiso/airootfs ]] && [[ -d /run/archiso/bootmnt ]] && ( mountpoint /run/archiso/airootfs &>/dev/null ) && ( mountpoint /run/archiso/bootmnt &>/dev/null ) && ( mountpoint /mnt &>/dev/null ) && [[ -d /mnt/boot ]] && ( mountpoint /mnt/boot &>/dev/null ) )
					then
						Repo_Enable
						InstallArch
					elif ( [[ -d /run/archiso/airootfs ]] && [[ -d /run/archiso/bootmnt ]] && ( mountpoint /run/archiso/airootfs &>/dev/null ) && ( mountpoint /run/archiso/bootmnt &>/dev/null ) ) && ( ( ! mountpoint /mnt ) || ( [[ ! -d /mnt/boot ]] && ( ! mountpoint /mnt/boot ) ) )
					then
						dialog --msgbox "Arch not installed" 0 0
					fi
					MainMenu "Install Arch *"
					;;

				"Configure Host +"|"Configure Host")
					# installed base but on live || not installed base but on live
					if ( [[ -d /run/archiso/airootfs ]] && [[ -d /run/archiso/bootmnt ]] && ( mountpoint /run/archiso/airootfs &>/dev/null ) && ( mountpoint /run/archiso/bootmnt &>/dev/null ) && ( mountpoint /mnt &>/dev/null ) && [[ -d /mnt/boot ]] && ( mountpoint /mnt/boot &>/dev/null ) ) || ( ( mountpoint / &>/dev/null ) && ( mountpoint /boot &>/dev/null ) )
					then
						ConfHost "set hostname *"

					# running live not installed system
					elif [[ -d /run/archiso/airootfs ]] && [[ -d /run/archiso/bootmnt ]] && ( mountpoint /run/archiso/airootfs &>/dev/null ) && ( mountpoint /run/archiso/bootmnt &>/dev/null ) && ( ! mountpoint /mnt &>/dev/null ) && [[ ! -d /mnt/boot ]]
					then
						dialog --msgbox "Cannot configure host without a Linux System installed" 0 0
					fi
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
							reboot now -f
							;;
						1) MainMenu "Reboot" ;;
					esac
					;;
			esac
			;;
		1) reset;exit ;;
	esac
}

trap '' 2
MainMenu "Partition Disk **" 3>&1 1>&2 2>&3
