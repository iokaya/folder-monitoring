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

function prepare_conda {
    # Preparing conda environment for python executions.
    # Setting env_name
    env_name="monitor-and-merge-files"
    # Conda init
    shell_name=$(basename "$SHELL")
    conda init "$shell_name"
    # Check if enviornment already exists
    env_exists=$(conda env list | grep -wq "$env_name" && echo true || echo false)
    # Check if environment exists and create if not
    if [ "$env_exists" == false ]; then
        echo "Creating new conda enviornment: $env_name"
        conda env create -f environment.yml
    fi
    # Update conda environment in case any changes
    conda env update -f environment.yml
    # Activate conda environment
    source ~/miniconda3/etc/profile.d/conda.sh
    conda activate $env_name
}

prepare_conda

# Function to call for merging files
function merge_files {
  # Check if the required arguments were provided
  if [ "$#" -lt 3 ]; then
    echo "Error: please provide a folder path, target file, and file pattern as arguments."
    echo "Usage: merge_files [folder_path] [target_file] [file_pattern]"
    return 1
  fi

  # Call the Python script with the provided arguments
  python merge_files.py "$1" "$2" "$3"
}

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
    # Deactivate conda environment
    conda deactivate
    # Exit
    exit 0
}

# Trap the INT signal and call the cleanup function
trap cleanup INT

# Loop over each folder in the list and start monitoring with fswatch in the background
for folder_line in $folder_list; do
    # Split the line into its three parts
    folder_to_observe=$(echo "$folder_line" | cut -d'|' -f1)
    target_file=$(echo "$folder_line" | cut -d'|' -f2)
    file_pattern=$(echo "$folder_line" | cut -d'|' -f3)

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
                # Run the merge function in case of new file
                python merge_files.py "$folder_to_observe" "$target_file" "$file_pattern" &
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
