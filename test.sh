#!/bin/bash

: '

part_table=$(dialog --menu "select partition table format" 0 0 0 "GPT" "(Global Partition Table) supports 128 partitions and boots from UEFI" "MBR" "(Master Boot Record) Supports 4 partitions and boots on legacy only" 3>&1 1>&2 2>&3)

[[ "$part_table" == "MBR" ]]
then
	echo "mbr"
fi
# && [[ "$part_table" == "MBR" ]] echo "mbr"

string="string"
string0="string"
string1="string1"
string2="string2"


if [[ $string = $string0 ]]
then
	printf "yes"
else
	printf "no"
fi

if [ "$string" = "$string0" ]
then
	if [ "$string1" = "$string2" ]
	then
		printf "yes"
	else
		printf "no"
	fi
else
	printf "sike"
fi

'
: '
GaugeMeter(){
	nice=($@)
	(
	c=0
	while [ $c -le 100 ]
	# while [ true ]
	    do
	        echo "#"
			echo $c
			echo "$c%"
	        ((c+=50))
	        ""
	        # ping google.com &>/dev/null
	done
	) | dialog --title "A Test Gauge With dialog" --gauge "Please wait ...." 0 0 0
}
nice=(yay -Ss ^brave$ &>/dev/null)
nice0=(sudo pacman -qQs ^plasmadesktop$ &>/dev/null)
ping0=(ping -c4 127.0.0.1 &>/dev/null)
GaugeMeter ${nice[@]}
'

: '
LOCALE=()





# exec 3<&0
# echo hello | while read -p "line: " line
while read -n1 -p "line: " line
do
  # echo We read the line: $line
  # echo is this correct?
  # read answer <&3
  echo -e "\n"You responded $line
  # echo You responded $answer
  if [[ $line == "y" ]]; then
  	echo  "Im broke"
  	break
  fi
done

for (( ; $Rescan -ne "n"; )); do
	read -p "wifi passphrase: " $pass
	iwctl station $wireless_dev connect $SSID
	if [[ $? -eq 0 ]]; then
		dialog --shadow --msgbox "connected successfully" 0 0
		# Rescan="n"
		break
	else
		dialog --shadow --msgbox "could not connect to $SSID" 0 0
		read -p "rescan and connect to an available network" Rescan
	fi
done

'

# dialog --shadow --msgbox "Created fstab entry" 0 0
# cat /etc/locale.gen | grep -i '#\w' | sed 's/#//' > locales.txt
# LOCALE=()
# while read langs
# do
# 	# echo "$langs $langs OFF"
# 	LOCALE+=("${langs}")
# 	LOCALE+=("${langs}")
# 	LOCALE+=(OFF)
#  done < locales.txt
#
# call1="w5dmh"
# call2="kd8pgb"
# message="here is a message"
#
# # open fd
# exec 3>&1
#
# # Store data to $VALUES variable
# VALUES=$(dialog --extra-button --extra-label "Stop Beacon" --ok-label "Start Beacon" --backtitle # "PSKBeacon Setup" --title "PSKBeacon" --form "Create a new beacon" 15 50 0 "From Callsign:" 1 1 # "$call2" 1 18 8 0 "To Callsign:" 2 1 "$call1" 2 18 8 0 "Message:" 3 1 "$message" 3 18 25 0 2>&1 # 1>&3)
#
# 		# close fd
# 		exec 3>&-
# 		ret=$?
#
# 		# close fd
# 		exec 3>&-
#
# 		case "$ret" in
# 		  0) choice='START' ;; # the 'ok' button
# 		  1) echo 'Cancel chosen'; exit ;;
# 		  3) choice='STOP' ;; # the 'extra' button
# 		  *) echo 'unexpected (ESC?)'; exit ;;
# 		esac
#
# 		# No exit, so start or stop chosen, and dialog should have
# 		# emitted values (updated, perhaps), stored in VALUES now
#
# 		{
# 		  read -r call1
# 		  read -r call2
# 		  read -r message
# 		} <<< "$VALUES"
#
# 		# setting beacon differently: include choice, and quote form values
# 		beacon="$choice: '$call1' de '$call2' '$message'"
#
# 		[ -e pskbeacon.txt ] && rm pskbeacon.txt
# 		# display values just entered
# 		echo $beacon >>pskbeacon.txt
#
# beacon="$call1 $call1 de $call2 $call2 $message"
# [ -e pskbeacon.txt ] && rm pskbeacon.txt
# display values just entered
# echo $beacon >>pskbeacon.txt





: '
regions=()
zones=()
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
unset regions_temp regions_dir_temp
region=$(dialog --menu "select the continent you are in" 0 0 0 "${regions[@]}" 3>&1 1>&2 2>&3)

# clear
# echo "$?"
# sleep 2
# echo -e "$?\n$region"
if [[ $? -eq 0 ]]; then
	echo "selcet"
elif [[ $? -eq 1 ]]; then
	echo "back"
fi

a=0
zone_temp=($(ls $region))
zone_temp_dir=($(ls -d $region/*))

for b in "${zone_temp_dir[@]}"
do
	if [[ -f "$b" ]] && [[ -r "$b" ]]
	then
		zones+=("$b")
		zones+=("${zone_temp[$a]}")
	fi
	((a+=1))
done
zone=$(dialog --cancel-label "back" --no-tags --menu "select the region you are in" 0 0 0 "${zones[@]}" 3>&1 1>&2 2>&3)

echo -e "$?\n$zone"
'


nice() {
	password="gr8"
}

password="nice"
echo $password
nice
echo $password
