#!/bin/sh
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#			TSBTRFS - Script to manage RSYNC backups in BTRFS systems			#
#																				#
# version ^1.1.0 - 09/08/23														#
# author: João Pedro Torres														#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

################################################################ text generators
readonly tag_rsync="TSBTRFS_RSYNC_LABEL"
readonly tag_bfreq="TSBTRFS_BACKUP_FREQUENCY"
readonly tag_cfreq="TSBTRFS_CLEANING_FREQUENCY"
readonly tag_old="TSBTRFS_OLD_BACKUPS_TO_KEEP"
readonly tag_new="TSBTRFS_NEW_BACKUPS_TO_KEEP"

helper="TSBTRFS v1.1.0 by João Pedro Torres

This is a Timeshift rsync backup automation tool for btrfs systems.
Timeshift  offers two modes of  backup for BTRFS file  systems: the
BTRFS  and the RSYNC modes.  The first  one fastly  creates  system
snapshots and store them in the system parition. The second one, in
the  other hand, creates  system backups possible  to be  stored in
other partitions, even in external drives.

This  makes possible to  the user to use both functionalities in an
easy way, by changing from btrfs snapshot mode to rsync, backup the
system  files to another  partition, and  set back  the btrfs  mode
automatically.

Syntax:
  sudo tsbtrfs --clear   or -c    Clear the list of rsync backups
  sudo tsbtrfs --backup  or -b    Create a rsync backup
  sudo tsbtrfs --init             (Re)Create config file
       tsbtrfs --help    or -h    Show all options
       tsbtrfs --log              Show the logging file
       tsbtrfs --log --clear      Clear logging file

Notes:
  sudo ts-btrfs --backup or -b    Set the RSYNC mode, create the
                                  snapshot,  then, set back  the
                                  BTRFS mode
  sudo ts-btrfs --clear  or -c    Set the RSYNC mode, remove the
                                  snapshots, then, set back  the
                                  BTRFS mode

Is needed to run 'sudo tsbtrfs --init' to start  the tool  usage.
After setting the configuration file using the command above, is
recommended to insert the '--backup' and '--clear' to su crontab
to be run after every boot (with the tag '@reboot', for example).
Doing  it, TSBTRFS will  do  the backups and cleanups  according
to the setted snapshot frequency."

# $1 label
# $2 old
# $3 new
tsbtrfs_conff() {
	echo "#########
## TSBTRFS Config -- version ^1.1.0
## Author: João Pedro Torres

## Set the device to receive the rsync backups by entering it's
## partition name
$tag_rsync=$1

## Set the number of old backups to not delete
$tag_old=$2

## Set the number of new backups to not delete
$tag_new=$3

## Set the frequency of the backups
$tag_bfreq=$4

## Set the frequency of the backup cleaning
$tag_cfreq=$5
"
}

####################################################################### messages
readonly warn2="WARNING 02: Backup has already been done before."
readonly warn3="WARNING 03: Partition to store rsync backups not found."
readonly warn4="WARNING 04: No snapshots enough for cleaning."
readonly warn1="WARNING 01: Missing config file. Run \"sudo tsbtrfs --init\"\
 to create it."

readonly err2="ERROR 02: Failed to set Timeshift RSYNC mode."
readonly err3="ERROR 03: Failed to make snapshot."
readonly err4="ERROR 04: Failed to set Timeshift BTRFS mode."
readonly err5="ERROR 05: Failed to get Timeshift list of RSYNC snapshots."
readonly err6="ERROR 06: Failed to delete snapshot"
readonly err1="ERROR 01: Entered value not allowed. Input a positive integer\
 value."

readonly msg1="Backup maker started."
readonly msg2="Setted Timeshift RSYNC mode."
readonly msg3="Snapshot successfully made."
readonly msg4="Setted Timeshift BTRFS mode."
readonly msg5="Backup maker finished!"
readonly msg6="Backup cleaner started."
readonly msg7="Getted Timeshift RSYNC snapshot list"
readonly msg8="Deleted snapshot"
readonly msg9="Backup cleaner finished!"

################################################################ constant values
readonly confd="/etc/tsbtrfs"
readonly conff="$confd/tsbtrfs.conf"
readonly loggf="$confd/tsbtrfs.log"
readonly flag="$confd/tsbtrfs_backup_done"

############################################################### auxiliar methods
create_logf() {
	if [ ! -d "$confd" ]; then													# if there is no config directory
		sudo mkdir "$confd"														# create the config directory
		echo "$warn1" && exit 1;												# warn to 'sudo tsbtrfs --init'
	elif [ ! -f "$conff" ]; then												# if there is no config file
		echo "$warn1" && exit 1;												# warn to 'sudo tsbtrfs --init'
	fi

	if [ ! -f "$loggf" ]; then													# if there id no logging file
		sudo touch "$loggf"														# create the logging file
		sudo echo "logging file creation: $(date)" > "$loggf"					# register logging for creating logging file
	fi
}

log() {
	create_logf																	# verify existence of the logging file
	sudo echo "[$(date +'%d/%m/%y %H:%M:%S')] $1" >> "$loggf"					# register logging in logging file
	echo "[$(date +'%d/%m/%y %H:%M:%S')] $1"									# inform the logging
}

tsbtrfs_get_info() {
	echo "$(grep -E "^$1=" $conff | cut -d "=" -f 2)"
}

# $1 date
tsbtrfs_get_concurrent_flag() {
	confd_len=$(expr length "$confd")											# config directory length
	flag_len=$(expr length "$flag" - $confd_len)								# flag name length
	output=$(ls $confd | grep ${flag:$confd_len+1}*)							# get list of flags
	freq="$(tsbtrfs_get_info $tag_bfreq)"										# get the setted backup frequency
	cur_date="$1" val=															# get parameter and declare auxiliar variable
	concurrent_flags=()															# found concurrent flags

	case $freq in
		"h")																	# if backup frequency is "h"
			while IFS= read -r line; do											# read all lines from output
				val=${line:$flag_len+6:2}										# flag's hour
				if [ "$val" = "${cur_date:6:2}" ]; then							# check if flag is concurrent by flag's hour
					concurrent_flags+=($line)									# insert flag into the list
				fi
			done <<< "$output"													# input output for reading
		;;
		"y")																	# if backup frequency is "y"
			while IFS= read -r line; do											# read all lines from output
				val=${line:$flag_len+4:2}										# flag's year
				if [ "$val" = "${cur_date:4:2}" ]; then							# check if flag is concurrent by flag's year
					concurrent_flags+=($line)									# insert flag into the list
				fi
			done <<< "$output"													# input output for reading
		;;
		"m")																	# if backup frequency is "m"
			while IFS= read -r line; do											# read all lines from output
				val=${line:$flag_len+2:2}										# flag's month
				if [ "$val" = "${cur_date:2:2}" ]; then							# check if flag is concurrent by flag's month
					concurrent_flags+=($line)									# insert flag into the list
				fi
			done <<< "$output"													# input output for reading
		;;
		"w")																	# if backup frequency is "w"
			while IFS= read -r line; do											# read all lines from output
				val=${line:$flag_len+12}										# flag's week
				if [ "$val" = "${cur_date:12}" ]; then							# check if flag is concurrent by flag's week
					concurrent_flags+=($line)									# insert flag into the list
				fi
			done <<< "$output"													# input output for reading
		;;
		"d")																	# if backup frequency is "d"
			while IFS= read -r line; do											# read all lines from output
				val=${line:$flag_len:2}											# flag's day
				if [ "$val" = "${cur_date:0:2}" ]; then							# check if flag is concurrent by flag's day
					concurrent_flags+=($line)									# insert flag into the list
				fi
			done <<< "$output"													# input output for reading
		;;
		*)
		;;
	esac

	echo "$concurrent_flags"
}

################################################################### menu methods
tsbtrfs_log() {
	if [ ! -f "$loggf" ]; then echo "$warn1" && exit 1; fi						# if there no logging file, warn it

	if [ "$1" = "--clear" ]; then												# if arguments requests logging file cleaning
		if [ ! "$EUID" -ne 0 ]; then											# if running with sudo
			sudo rm -f "$loggf"													# remove existent logging file
			sudo touch "$loggf"													# recreate logging file
			sudo echo "logging file creation: $(date)" > "$loggf"				# register logging for creating logging file
		else																	# if not running with sudo
			echo "This command should being run with sudo privilegies."			# show instructions
			echo "Run \"sudo tsbtrfs --log --clear\" instead."
		fi
	else cat "$loggf"															# show logging file
	fi
}

tsbtrfs_helper() {
	echo "$helper";																# show helper
}

tsbtrfs_init() {
	if [ ! "$EUID" -ne 0 ]; then												# if running with sudo
		echo "If the partition where shoud be stored the bakups isn't labeled,"	# show instruction for disk label
		echo "LABEL IT, so the script will work as expected."
		read -r -p "Enter the disk LABEL for rsync backups: " label				# read input for rsync disk label

		echo "Choose how many of the oldest backups will shall not be removed."	# show instruction for keep old backups
		read -r -p "Enter the number of old snapshots to keep: " old			# read input for old backups to keep

		echo "Choose how many of the newest backups will shall not be removed."	# show instruction for keep new backups
		read -r -p "Enter the number of new snapshots to keep: " new			# read input for new backups to keep

		echo "Choose the frequency of the backups by typing one letter."		# show instruction for keep new backups
		echo "Unvaliable options will be interpreted as custom."
		echo "[y]yearly [m]monthly [w]weekly [d]dayly [h]hourly [c]custom"		# show options
		read -r -p "Enter the letter to tag the backup frequency: " b_freq		# read input for new backups to keep

		echo "Choose the frequency of the cleaning by typing one letter."		# show instruction for keep new backups
		echo "Unvaliable options will be interpreted as custom."
		echo "[y]yearly [m]monthly [w]weekly [d]dayly [h]hourly [c]custom"		# show options
		read -r -p "Enter the letter to tag the cleaning frequency: " c_freq	# read input for new backups to keep

		if [ ! -d $confd ]; then												# if there is no config directory
			sudo mkdir "$confd"													# create config directory
			sudo touch "$conff" "$loggf"										# create config and logging files
			sudo echo "logging file creation: $(date)" > "$loggf"				# register logging for creating logging file
		fi

		# check and normalize input for b_freq
		if [ $b_freq != "y" ] && [ $b_freq != "m" ] && [ $b_freq != "w" ] &&
		[ $b_freq != "d" ] && [ $b_freq != "h" ] && [ $b_freq != "c" ]; then
			b_freq="c"
		fi

		# check and normalize input for c_freq
		if [ $c_freq != "y" ] && [ $c_freq != "m" ] && [ $c_freq != "w" ] &&
		[ $c_freq != "d" ] && [ $c_freq != "h" ] && [ $c_freq != "c" ]; then
			c_freq="c"
		fi

		if [ ! -f $conff ]; then touch "$conff"; fi								# if there is no config file, create it
		echo "$(tsbtrfs_conff $label $old $new $b_freq $c_freq)" > $conff		# write into the config file
	else																		# if not running with sudo
		echo "This command should being run with sudo privilegies."				# show instructions
		echo "Run \"sudo tsbtrfs --init\" instead."
	fi
}

tsbtrfs_maker() {
	if [ ! "$EUID" -ne 0 ]; then												# if running with sudo
		if [ ! -d "$confd" ] | [ ! -f "$conff" ]; then							# if there is no config directory or file
			echo "$warn1" && exit 1												# warn missing config file
		fi
		if [ ! -f "$loggf" ]; then												# if there is no logging file
			sudo touch "$loggf";												# create logging file
			sudo echo "logging file creation: $(date)" > "$loggf"				# register logging for creating logging file
		fi

		tag="$(tsbtrfs_get_info "$tag_bfreq")"									# get frequency of execution
		rsync="$(tsbtrfs_get_info "$tag_rsync")"								# get device label
		rsync=$(sudo blkid | grep "LABEL=\"$rsync\"" | cut -d ':' -f 1)			# get device
		date=$(date +%d%m%y%H%M%S%V) today=$(date +"%d/%m/%Y %H:%M:%S")			# get current date

		log "#################################################### Backup maker" # register logging for starting task
		if [ "$rsync" != "" ]; then												# if the partition was found
			concurrent_flags=$(echo "$(tsbtrfs_get_concurrent_flag $date)")		# get flags that may concur with the current backup

			if [ "$concurrent_flags" = "" ]; then								# if file flag does not exist
				log "$msg1"														# register log for statrting process
				sudo timeshift --rsync --snapshot-device "$rsync"				# set Timeshift to RSYNC mode
				status=$?														# store the exit status of the previous command
				if [ $status -ne 0 ]; then										# if exit status is not 0
					log "$err2" && exit 2										# register logging for error while setting rsync mode
				else															# if exit status is 0
					log "$msg2"													# register log for setted rsync mode
				fi

				sudo timeshift --create --comments "$today home backup"			# make Timeshift rsync snapshot
				status=$?														# store the exit status of the previous command
				if [ $status -ne 0 ]; then										# if exit status is not 0
					log "$err3" && exit 3										# regiter log for error while creating snapshot
				else															# if exit status is 0
					log "$msg3"													# register log for made snapshot
				fi

				sudo timeshift --btrfs --snapshot-device "/dev/dm-0"			# set Timeshift to BTRFS mode
				status=$?														# store the exit status of the previous command
				if [ $status -ne 0 ]; then										# if exit status is not 0
					log "$err4" && exit 4										# register logging for error while setting btrfs mode
				else															# if exit status is 0
					log "$msg4"													# register log for setted btrfs mode
				fi

				sudo rm -f "${flag}"*											# remove past flags
				sudo touch "${flag}_${date}"									# create daily flag
				log "$msg5"														# register log for backup maker done
			else																# if flag already exists
				log "$warn2"													# register log for backup already done before
			fi
		else																	# if partition not found
			log "$warn3"														# register log for parition not found
		fi
	else																		# if not running with sudo
		echo "This command should being run with sudo privilegies."				# show instructions
		echo "Run \"sudo tsbtrfs [--backup | -b]\" instead."
	fi
}

tsbtrfs_cleaner() {
	if [ ! "$EUID" -ne 0 ]; then												# if running with sudo
		if [ ! -d "$confd" ] | [ ! -f "$conff" ]; then							# if there is no config directory or file
			echo "$warn1" && exit 1												# warn missing config file
		fi
		if [ ! -f "$loggf" ]; then												# if there is no logging file
			sudo touch "$loggf";												# create logging file
			sudo echo "logging file creation: $(date)" > "$loggf"				# register logging for creating logging file
		fi

		rsync="$(tsbtrfs_get_info "$tag_rsync")"								# get device label
		old="$(tsbtrfs_get_info "$tag_old")"									# get number of old snapshots to keep
		new="$(tsbtrfs_get_info "$tag_new")"									# get number of new snapshots to keep
		rsync=$(sudo blkid | grep "LABEL=\"$rsync\"" | cut -d ':' -f 1)			# get device

		log "################################################## Backup cleaner" # register logging for starting task
		if [ "$rsync" != "" ]; then												# if the partition was found
			log "$msg6"															# register logging for starting the process

			sudo timeshift --rsync --snapshot-device "$rsync"					# set Timeshift to RSYNC mode
			status=$?															# store the exit status of the previous command
			if [ $status -ne 0 ]; then											# if exit status is not 0
				log $err2 && exit 2												# register logging for error while setting rsync mode
			else																# if exit status is 0
				log "$msg2"														# register logging for setting rsync mode
			fi

			output=$(sudo timeshift --list)										# get list of snapshots
			status=$?															# store the exit status of the previous command
			if [ $status -ne 0 ]; then											# if exit status is not 0
				log $err5 && exit 5												# register logging for error while getting list of snapshots
			else																# if exit status is 0
				log "$msg7"														# register logging for getting list of snapshots
			fi

			n_snapshots=$(echo "$output" | grep -nE '^---*$' | cut -d ':' -f 1)	# find the start line of listing snapshots
			n_snapshots=$(echo "$output" | sed -n "$((n_snapshots + 1)),\$p")	# get list of snapshots, which is below the pattern "---"
			n_snapshots=$(echo "$n_snapshots" | wc -l)							# count number of snapshots

			if [ $n_snapshots -gt "$((old + new))" ]; then						# if number of snapshots is greater than the number of snapshots to keep
				n_snapshots=$((n_snapshots - 1))								# get number of snapshots from 0

				for (( i = old; i <= n_snapshots - new; i++)); do				# repeat for the number of deletitions
					echo "$((old))" | sudo timeshift --delete					# delete the oldest snapshot allowed to delete
					status=$?													# store the exit status of the previous command
					if [ $status -ne 0 ]; then									# if exit status is not 0
						log "$err6" && exit 8									# register loggin for error while deleting snapshot
					else														# if exit status is 0
						log "$msg8"												# resgister log for deleted snapshot
					fi
				done
			else																# if number of snapshots is <= than the number of snapshots to keep
				log "$warn4"													# register logging for no snapshots enough
			fi

			sudo timeshift --btrfs --snapshot-device "/dev/dm-0"				# set Timeshift to BTRFS mode
			status=$?															# store the exit status of the previous command
			if [ $status -ne 0 ]; then											# if the exit status is not 0
				log $err4 && exit 4												# register logging for error while setting btrfs mode
			else																# if the exit status is 0
				log "$msg4"														# register logging for setting btrfs mode
			fi

			log "$msg9"															# register logging for ending the process
		else																	# if the partition was not found
			log "$warn3"														# register logging for device not found
		fi
	else																		# if not running with sudo
		echo "This command should being run with sudo privilegies."				# show instructions
		echo "Run \"sudo tsbtrfs [--clear | -c]\" instead."
	fi
}

case $1 in
	"--backup" | "-b")
		tsbtrfs_maker
	;;
	"--clear" | "-c")
		tsbtrfs_cleaner
	;;
	"--help" | "-h")
		tsbtrfs_helper
	;;
	"--log")
		tsbtrfs_log $2
	;;
	"--init")
		tsbtrfs_init
	;;
	*)
		tsbtrfs_helper
	;;
esac

exit 0
