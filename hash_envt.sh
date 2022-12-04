#!/bin/bash

CONF_VERBOSE=1

if [ "$1" != "-v" ]; then
	CONF_VERBOSE=0
fi


KERNEL_IMAGE=/boot/vmlinuz-5.1.18-300.fc30.x86_64
SYSTEM_MAP=/boot/System.map-5.1.18-300.fc30.x86_64

# ----------------------------------------------------------- #

REQUIRED_HASHES=($KERNEL_IMAGE $SYSTEM_MAP)

# ----------------------------------------------------------- #

RUNNING_HASH=""

for entry in ${REQUIRED_HASHES[@]}; do
	current_hash=$(md5sum $entry | grep -o "^\w*\b")
	RUNNING_HASH="$RUNNING_HASH$current_hash"

	if [ $CONF_VERBOSE -eq 1 ]; then
		#echo $entry -- $current_hash
		printf '%s %-15s: %s\n' "$entry" "$current_hash"
	fi
done

SYSTEM_HASH=$(echo "$RUNNING_HASH" | md5sum | grep -o "^\w*\b")

echo "System Hash: $SYSTEM_HASH" |& tee system_hash




