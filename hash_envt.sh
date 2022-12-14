#!/bin/bash

CONF_VERBOSE=0

while getopts 've:' OPTION; do
  	case "$OPTION" in
    e)
		expt_dir="$OPTARG"
    	;;
    v)
		CONF_VERBOSE=1
		;;
    ?)
		echo "Usage: $0 [-v] [-e experiment_path]"
		exit 1
		;;
  	esac
done

# Last produced system hash
LAST_PRODUCED_HASH=""

# Params:
#   $1 -- array of required files/hashes
#   $2 -- output file
#   $3 -- [bool] should use file contents
function ProduceMd5Hash {
	# Newline for cosmetics
	if [ $CONF_VERBOSE -eq 1 ]; then echo ""; fi

	RUNNING_HASH=""
	rm -rf $2.details

	for entry in ${REQUIRED_HASHES[@]}; do
		if [ $3 -eq 1 ]; then
			current_hash=$(cat $entry | md5sum | grep -o "^\w*\b")
		else
			current_hash=$(md5sum $entry | grep -o "^\w*\b")
		fi

		RUNNING_HASH="$RUNNING_HASH$current_hash"

		if [ $CONF_VERBOSE -eq 1 ]; then
			printf '%-50s %s\n' "$entry" "$current_hash"
		fi

		printf '%-50s %s\n' "$entry" "$current_hash" >> $2.details
	done

	LAST_PRODUCED_HASH=$(echo "$RUNNING_HASH" | md5sum | grep -o "^\w*\b")

	echo "$LAST_PRODUCED_HASH" > $2
}

# --------------- Software Requirements --------------------- #

KERNEL_IMAGE=$(grubby --default-kernel)
SYSTEM_MAP=$(ls /boot/System.map-`uname -r`)
BOOT_CMDLINE=/proc/cmdline

# --------------- Software Required Hashse ------------------ #

REQUIRED_HASHES=($KERNEL_IMAGE $SYSTEM_MAP $BOOT_CMDLINE)

if [ -z "$expt_dir" ]; then
	read -e -p "Experiment directory: " expt_dir
fi

if [ -f "$expt_dir/experiment_binaries" ]; then
	while read binary; do
  		REQUIRED_HASHES+=($binary)
	done < "$expt_dir/experiment_binaries"
fi

# ---------------- Producing Software Hash ------------------ #

ProduceMd5Hash REQUIRED_HASHES "software_hash" 0
printf "Software System Hash : $LAST_PRODUCED_HASH\n"

SOFTWARE_HASH=$LAST_PRODUCED_HASH

# --------------- Hardware Requirements --------------------- #

echo "$(lscpu)" > cpu.info
echo "$(sudo lspci | grep -i wireless)" > wireless_card.info
echo "$(sudo lspci | grep -i ethernet)" > ethernet_card.info
echo "$(cat /proc/meminfo)" > mem.info
echo "$(lsblk)" > disk.info

# Check for turboboost
if [ -f "/sys/devices/system/cpu/cpufreq/boost" ]; then
	state="$(cat /sys/devices/system/cpu/cpufreq/boost)"
	if [ $state -eq "1" ]; then
		echo "Turboboost: on" > turboboost.info
	else
		echo "Turboboost: off" > turboboost.info
	fi
else
	state="$(cat /sys/devices/system/cpu/intel_pstate/no_turbo)"
	if [ $state -eq "0" ]; then
		echo "Turboboost: on" > turboboost.info
	else
		echo "Turboboost: off" > turboboost.info
	fi
fi

# Removing runtime-variability from cpu info
awk '!/CPU MHz:/' cpu.info > cputmp && mv cputmp cpu.info
awk '!/BogoMIPS:/' cpu.info > cputmp && mv cputmp cpu.info

CPU_INFO=cpu.info
NETWORK_CARD_WIRELESS_INFO=wireless_card.info
NETWORK_CARD_ETHERNET_INFO=ethernet_card.info
TURBOBOOST_INFO=turboboost.info

REQUIRED_HASHES=($CPU_INFO $NETWORK_CARD_WIRELESS_INFO $NETWORK_CARD_ETHERNET_INFO $TURBOBOOST_INFO)

# ---------------- Producing Hardware Hash ------------------ #

ProduceMd5Hash REQUIRED_HASHES "hardware_hash" 1
printf "Hardware System Hash : $LAST_PRODUCED_HASH\n"

HARDWARE_HASH=$LAST_PRODUCED_HASH

# -------------- Producing Total System Hash ---------------- #

SYSTEM_HASH_STRING="$SOFTWARE_HASH$HARDWARE_HASH"
TOTAL_SYSTEM_HASH=$(echo "$SYSTEM_HASH_STRING" | md5sum | grep -o "^\w*\b")

echo "$TOTAL_SYSTEM_HASH" > total_system_hash
printf "Total System Hash    : $TOTAL_SYSTEM_HASH\n"

# ----------------------- Cleanup --------------------------- #

SYSTEM_HASH_DIR=$(hostname)-system-hash

mkdir -p $SYSTEM_HASH_DIR
mv disk.info mem.info software_hash* hardware_hash* total_system_hash ./$SYSTEM_HASH_DIR/

for file in ${REQUIRED_HASHES[@]}; do
	mv $file ./$SYSTEM_HASH_DIR/
done

# Save boot command line to disk
echo "$(cat /proc/cmdline)" > ./$SYSTEM_HASH_DIR/boot_cmdline.info
