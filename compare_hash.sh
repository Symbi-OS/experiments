#!/bin/bash
SYSTEM_HASH_DIR=$(hostname)-system-hash

if [ ! -d "$SYSTEM_HASH_DIR" ]; then
    echo "Error: no system hash detected for the current system"
    exit 1
fi

if [ -n "$1" ]; then
    REFERENCE_SYSTEM_HASH_PATH=$1
else
    read -e -p "Reference system-hash path: " REFERENCE_SYSTEM_HASH_PATH
fi

if [ ! -d "$REFERENCE_SYSTEM_HASH_PATH" ]; then
    echo "Error: could not find reference system hash"
    exit 1
fi

REF_SOFTWARE_HASH=$(cat $REFERENCE_SYSTEM_HASH_PATH/software_hash)
CUR_SOFTWARE_HASH=$(cat $SYSTEM_HASH_DIR/software_hash)

REF_HARDWARE_HASH=$(cat $REFERENCE_SYSTEM_HASH_PATH/hardware_hash)
CUR_HARDWARE_HASH=$(cat $SYSTEM_HASH_DIR/hardware_hash)

# Params:
#    $1 -- fileA to compare
#    $2 -- fileB to compare
function PrintSoftwareDiffs {
    diffs=$(grep -v -F -x -f $1 $2 | awk '{print $1;}')
    readarray -t <<< $diffs
    for diff in ${MAPFILE[@]}; do
        printf "    \033[1;33m$diff\033[0m\n"
        if [[ $diff == *"/proc/cmdline"* ]]; then
            ref_cmdline=($(cat $REFERENCE_SYSTEM_HASH_PATH/boot_cmdline.info))
            cur_cmdline=($(cat $SYSTEM_HASH_DIR/boot_cmdline.info))

            cmdline_diffs=$(echo ${ref_cmdline[@]} ${cur_cmdline[@]} | tr ' ' '\n' | sort | uniq -u)
            while IFS= read -r param; do
                #printf "        * $param\n"
                if [[ " ${cur_cmdline[@]} " =~ .*\ $param\ .* ]]; then
                    printf "        * $param (found)\n"
                else
                    printf "        * $param (missing)\n"
                fi
            done <<< "$cmdline_diffs"
        fi
    done

    printf "\n"
}

# Params:
#    $1 -- fileA to compare
#    $2 -- fileB to compare
function PrintHardwareDiffs {
    diffs=$(grep -v -F -x -f $1 $2 | awk '{print $1;}')
    readarray -t <<< $diffs
    for diff in ${MAPFILE[@]}; do
        printf "    \033[1;33m$diff\033[0m\n"

        ref_file=$REFERENCE_SYSTEM_HASH_PATH/$diff
        cur_file=$SYSTEM_HASH_DIR/$diff

        SAVEIFS=$IFS   # Save current IFS (Internal Field Separator)
        IFS=$'\n'      # Change IFS to newline char
        
        file_diff_items=$(diff -w --new-line-format="" --unchanged-line-format="" $ref_file $cur_file)
        file_diffs=($file_diff_items)
        for (( i=0; i<${#file_diffs[@]}; i++ )); do
            printf "        - \033[1;31m${file_diffs[$i]}\033[0m\n"
        done

        file_diff_items=$(diff -w --new-line-format="" --unchanged-line-format="" $cur_file $ref_file)
        file_diffs=($file_diff_items)
        for (( i=0; i<${#file_diffs[@]}; i++ )); do
            printf "        + \033[1;32m${file_diffs[$i]}\033[0m\n"
        done

        IFS=$SAVEIFS   # Restore original IFS
    done

    printf "\n"
}

# ------------ Searching Software Differences ------------ #
function FindSoftwareDifferences {
    printf "\n*---- Software Differences: ----*\n"
    ref_details=$REFERENCE_SYSTEM_HASH_PATH/software_hash.details
    cur_details=$SYSTEM_HASH_DIR/software_hash.details

    PrintSoftwareDiffs $ref_details $cur_details
}

# ------------ Searching Hardware Differences ------------ #
function FindHardwareDifferences {
    printf "\n*---- Hardware Differences: ----*\n"
    ref_details=$REFERENCE_SYSTEM_HASH_PATH/hardware_hash.details
    cur_details=$SYSTEM_HASH_DIR/hardware_hash.details

    PrintHardwareDiffs $ref_details $cur_details
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
