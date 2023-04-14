#!/bin/bash

# Parse the command-line arguments
if [ $# -ne 1 ]; then
    echo "Usage: $0 <folder_list_file>"
    exit 1
fi

folder_list_file=$1

# Read the list of folders to observe from the file
folder_list=$(cat $folder_list_file)

# Function to handle the INT signal
function cleanup {
    pkill -P $$
    exit 0
}

# Trap the INT signal and call the cleanup function
trap cleanup INT

# Loop over each folder in the list and start monitoring with fswatch in the background
for folder_to_observe in $folder_list; do
    echo "Monitoring folder $folder_to_observe"

    fswatch -r $folder_to_observe | while read file_event; do
        # Check if the parent shell process is still running
        if ! kill -0 $$; then
            exit
        fi

        # Extract the path to the file that was changed
        changed_file=$(echo "${file_event}" | awk -F' ' '{print $1}')

        # Get the file name without the path
        filename=$(basename "$changed_file")

        # Create a temporary file name based on the full path to the file
        temp_file="/tmp/monitor_$(echo "$changed_file" | sed 's/\//__/g;s/-/_/g').tmp"

        # Determine the type of operation that was performed on the file
        current_time=$(date +%s)
        if [ -f "$changed_file" ]; then
            if [ ! -e "$temp_file" ]; then
                touch "$temp_file"
                operation="added"
            else
                modification_time=$(stat -f "%m" "$changed_file")
                time_diff=$(( current_time - modification_time ))

                if [ $time_diff -lt 5 ]; then
                    operation="modified"
                else
                    operation="unknown"
                fi
            fi
        elif [ -e "$temp_file" ]; then
            rm "$temp_file"
            operation="removed"
        else
            operation="unknown"
        fi

        # Print the name of the file and the type of operation
        echo "File ${filename} ${operation} in folder $folder_to_observe."
    done &
done

# Wait for all fswatch processes to finish before exiting the script
wait