#!/bin/bash
SYSTEM_HASH_DIR=$(hostname)-system-hash

read -e -p "Reference system-hash path: " REFERENCE_SYSTEM_HASH_PATH

REF_SOFTWARE_HASH=$(cat $REFERENCE_SYSTEM_HASH_PATH/software_hash)
CUR_SOFTWARE_HASH=$(cat $SYSTEM_HASH_DIR/software_hash)

REF_HARDWARE_HASH=$(cat $REFERENCE_SYSTEM_HASH_PATH/hardware_hash)
CUR_HARDWARE_HASH=$(cat $SYSTEM_HASH_DIR/hardware_hash)

# Params:
#    $1 -- fileA to compare
#    $2 -- fileB to compare
function PrintDiffs {
    diffs=$(grep -v -F -x -f $1 $2 | awk '{print $1;}')
    readarray -t <<< $diffs
    for diff in ${MAPFILE[@]}; do
        printf "    \033[1;33m$diff\033[0m\n"
    done

    printf "\n"
}

# ------------ Searching Software Differences ------------ #
function FindSoftwareDifferences {
    printf "\n*---- Software Differences: ----*\n"
    ref_details=$REFERENCE_SYSTEM_HASH_PATH/software_hash.details
    cur_details=$SYSTEM_HASH_DIR/software_hash.details

    PrintDiffs $ref_details $cur_details
}

# ------------ Searching Hardware Differences ------------ #
function FindHardwareDifferences {
    printf "\n*---- Hardware Differences: ----*\n"
    ref_details=$REFERENCE_SYSTEM_HASH_PATH/hardware_hash.details
    cur_details=$SYSTEM_HASH_DIR/hardware_hash.details

    PrintDiffs $ref_details $cur_details
}

# ------------ CHECKING FOR SOFTWARE DIFFS ------------ #
if [ $REF_SOFTWARE_HASH != $CUR_SOFTWARE_HASH ]; then
    printf "[\033[0;31m-\033[0m] Software Hash: \033[0;31mdifferent\033[0m\n"
    FindSoftwareDifferences
else
    printf "[\033[0;32m+\033[0m] Software Hash: \033[0;32mmatching\033[0m\n"
fi

# ------------ CHECKING FOR HARDWARE DIFFS ------------ #
if [ $REF_HARDWARE_HASH != $CUR_HARDWARE_HASH ]; then
    printf "[\033[0;31m-\033[0m] Hardware Hash: \033[0;31mdifferent\033[0m\n"
    FindHardwareDifferences
else
    printf "[\033[0;32m+\033[0m] Hardware Hash: \033[0;32mmatching\033[0m\n"
fi
