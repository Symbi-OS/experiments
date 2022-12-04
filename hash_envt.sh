#!/bin/bash

CONF_VERBOSE=1

if [ "$1" != "-v" ]; then
	CONF_VERBOSE=0
fi

# Last produced system hash
LAST_PRODUCED_HASH=""

# Params:
#   $1 -- array of required files/hashes
#   $2 -- output file
#   $3 -- [bool] should use file contents
function ProduceMd5Hash {
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
	if [ $CONF_VERBOSE -eq 1 ]; then echo ""; fi

	LAST_PRODUCED_HASH=$(echo "$RUNNING_HASH" | md5sum | grep -o "^\w*\b")

	echo "$LAST_PRODUCED_HASH" > $2
}

# --------------- Software Requirements --------------------- #

KERNEL_IMAGE=/boot/vmlinuz-5.1.18-300.fc30.x86_64
SYSTEM_MAP=/boot/System.map-5.1.18-300.fc30.x86_64
BOOT_CMDLINE=/proc/cmdline

# --------------- Software Required Hashse ------------------ #

REQUIRED_HASHES=($KERNEL_IMAGE $SYSTEM_MAP $BOOT_CMDLINE)

read -p "Experiment directory: " expt_dir

if [ -f "$expt_dir/experiment_binaries" ]; then
	while read binary; do
  		REQUIRED_HASHES+=($binary)
	done < "$expt_dir/experiment_binaries"
fi

# ---------------- Producing Software Hash ------------------ #

ProduceMd5Hash REQUIRED_HASHES "software_hash" 0
printf "Software System Hash: $LAST_PRODUCED_HASH\n\n"

SOFTWARE_HASH=$LAST_PRODUCED_HASH

# --------------- Hardware Requirements --------------------- #

echo "$(lscpu)" > cpu.info
echo "$(sudo lspci | grep -i wireless)" > wireless_card.info
echo "$(sudo lspci | grep -i ethernet)" > ethernet_card.info
echo "$(sudo dmidecode --type 17)" > mem.info

# Removing runtime-variability from cpu info
awk '!/CPU MHz:/' cpu.info > cputmp && mv cputmp cpu.info

CPU_INFO=cpu.info
NETWORK_CARD_WIRELESS_INFO=wireless_card.info
NETWORK_CARD_ETHERNET_INFO=ethernet_card.info
MEM_INFO=mem.info

REQUIRED_HASHES=($CPU_INFO $NETWORK_CARD_WIRELESS_INFO $NETWORK_CARD_ETHERNET_INFO $MEM_INFO)

# ---------------- Producing Hardware Hash ------------------ #

ProduceMd5Hash REQUIRED_HASHES "hardware_hash" 1
printf "Hardware System Hash: $LAST_PRODUCED_HASH\n\n"

HARDWARE_HASH=$LAST_PRODUCED_HASH

# ----------------------- Cleanup --------------------------- #

rm -rf cpu.info mem.info wireless_card.info ethernet_card.info
