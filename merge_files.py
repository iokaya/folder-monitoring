import os
import sys
import glob
from natsort import natsorted

# Define the help text
help_text = """
Usage: python merge_files.py [folder_path] [target_file] [file_pattern]

Merge the content of text files in a folder that match a certain pattern and order the merged content by filename.

Arguments:
  folder_path    The path to the folder containing the text files to merge.
  target_file    The path and name of the target file to write the merged content to.
  file_pattern   The file pattern to match for the source files.

Example:
  python merge_files.py /path/to/folder /path/to/target_file example_*
"""

# Check if a folder path, target file, and file pattern were provided as arguments
if len(sys.argv) < 4:
    print("Error: please provide a folder path, target file, and file pattern as arguments.")
    print(help_text)
    sys.exit(1)

# Get the folder path, target file path, and file pattern from the arguments
folder_path = sys.argv[1]
target_file_path = sys.argv[2]
file_pattern = sys.argv[3]

# Get a list of all files in the folder that match the pattern using glob
file_list = glob.glob(os.path.join(folder_path, file_pattern))

# Sort the file list by filename using natsort
file_list = natsorted(file_list)

# Initialize an empty string to store the merged content
merged_content = ""

# Loop over each file in the list and append its content to the merged content string
for filename in file_list:
    print(f"Writing file: {filename}")
    with open(filename, "r") as f:
        merged_content += f.read()

# Write the merged content to the target file
with open(target_file_path, "w") as f:
    f.write(merged_content)

# Print a success message
print(f"Merged content written to {target_file_path}.")
