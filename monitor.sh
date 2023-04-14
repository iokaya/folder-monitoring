#!/bin/bash

# Define usage and help messages
usage="Usage: $0 [-c] <folder_list_file>
    -c: create temporary files for existing files in folders
    -h, --help: display this help message"
help_msg="Monitor one or more folders for changes and print the names of files that were added, modified, or removed.

Arguments:
    -c, --create-files: create temporary files for existing files in the folders to monitor
    -h, --help: display this help message

The script reads the names of the folders to monitor from a file specified by <folder_list_file>. The file should contain one folder path per line."

# Parse the command-line arguments
if [ $# -eq 0 ] || [ $# -gt 2 ]; then
    echo "$usage"
    exit 1
fi

while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--create-files)
            create_files=true
            shift
            ;;
        -h|--help)
            echo "$help_msg"
            exit 0
            ;;
        *)
            if [ -z "$folder_list_file" ]; then
                folder_list_file=$1
            else
                echo "Invalid argument: $1"
                echo "$usage"
                exit 1
            fi
            shift
            ;;
    esac
done

# Check if the folder list file was specified
if [ -z "$folder_list_file" ]; then
    echo "Error: no folder list file specified."
    echo "$usage"
    exit 1
fi

# Read the list of folders to observe from the file
folder_list=$(cat "$folder_list_file")

# Function to handle the INT signal
function cleanup {
    # Terminate all child processes before exiting the script
    pkill -P $$
    # Remove any monitor files that were created
    rm -f /tmp/monitor_*
    exit 0
}

# Trap the INT signal and call the cleanup function
trap cleanup INT

# Loop over each folder in the list and start monitoring with fswatch in the background
for folder_to_observe in $folder_list; do
    echo "Monitoring folder $folder_to_observe"

    # Create temporary files for existing files in the folder if the -c option was specified
    if [ "$create_files" == true ]; then
        find "$folder_to_observe" -type f -print0 | while read -d $'\0' file; do
            temp_file="/tmp/monitor_$(echo "$file" | sed "s#^${folder_to_observe}#${folder_to_observe}#;s#/#__#g").tmp"
            touch "$temp_file"
        done
    fi

    # Start monitoring the folder with fswatch in the background
    fswatch -r "$folder_to_observe" | while read file_event; do
        # Check if the parent shell process is still running
        if ! kill -0 $$; then
            exit
        fi

        # Extract the path to the file that was changed
        changed_file=$(echo "${file_event}" | awk -F' ' '{print $1}')

        # Get the file name without the path
        filename=$(basename "$changed_file")

        # Create a temporary file name based on the full path to the file
        temp_file="/tmp/monitor_$(echo "$changed_file" | sed 's/\//__/g').tmp"

        # Determine the type of operation that was performed on the file
        current_time=$(date +%s)
        if [ -f "$changed_file" ]; then
            # The file exists and was either added or modified
            if [ ! -e "$temp_file" ]; then
                # The file was just added
                touch "$temp_file"
                operation="added"
            else
                # The file was modified
                modification_time=$(stat -f "%m" "$changed_file")
                time_diff=$(( current_time - modification_time ))

                if [ $time_diff -lt 5 ]; then
                    operation="modified"
                else
                    # If the modification time is older than 5 seconds, assume the operation is unknown
                    operation="unknown"
                fi
            fi
        elif [ -e "$temp_file" ]; then
            # The file was removed
            rm "$temp_file"
            operation="removed"
        else
            # The file does not exist and was not previously being monitored
            operation="unknown"
        fi

        # Print the name of the file and the type of operation
        echo "File ${filename} ${operation} in folder $folder_to_observe"
    done &
done

# Wait for all fswatch processes to finish before exiting the script
wait
