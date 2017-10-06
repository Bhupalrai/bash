#!/bin/bash
#######################################################################
#                    Backup linux users
#----------------------------------------------------------------------
# Backup all users including root
#
#######################################################################

#
# globals
users_list=()
dest_dir="/backup/rpy_1_backup"

#
# add users to list
users_list+=(root)
for username in `ls /home`; do
        users_list+=(${username})
done

#
# inform user before sync
echo "Syncing users"
echo "-----------------------------------------"
for username in ${users_list[@]}; do
        echo $username
done

#
# sync
for username in ${users_list[@]}; do
        mkdir -p "${dest_dir}"
        [ $? -ne 0 ] && { echo "error creating directory ${dest_dir}, skipping..."; continue; }

        if [ "${username}" = "root" ]; then
                source_home="/root"
        else
                source_home="/home/${username}"
        fi
        rsync -rlptDq  --no-links "${source_home}" "${dest_dir}"
done

#
# done
echo "script complete"
