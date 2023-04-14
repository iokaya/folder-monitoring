# Folder Monitoring & File Merging

> :warning: **This is currently working on `MacOS` (and probably on `Linux`) but not tested on `Windows`**
---

## Prerequisites
- `Conda` installed (or `miniconda`)
- `fswatch` installed

---

## Usage

### Example
-  Command to run is as seen below.
```bash
bash -i monitor.sh ./folders -c
```
- `./folder` represents the folders file that has 3 strings that are seperated with pipe symbol ( - `|` - ).
    - The first one is the folder to monitor
    - The second one is the target file to write merged result
    - The last one is the pattern of the filename - in case we do not want to have all the files to be merged
- In this example we are seeing the full path of my development environment, so this has to be replaced before running
```txt
/Users/ikaya/projects/sh/source|/Users/ikaya/projects/sh/target/dtg.txt|*dtg*
```
- `-c` represents the option to create temporary files to trail changes (we are creating temporary clones of all the files to distinguish newly added/modified ones). If this option is enabled, then the script will create temporary clones of all the files that are already inside the folder

---

## Comments
I created this script just to make an introduction to what we can do on the matter you told about. This has a lot of ways to go, like platform independent execution, having the checks of file patterns on shell side and only monitor the changes on those files, integrate with snowflake, integrate with aws s3 buckets for auto uploading the merged file etc. These all can be achiavable, we can talk on them.

I have left those source and target folders and files intentionally, just to demonstrate that the filenames and versions are taken into account.

As I said, this just the initial,we have a lot of way to go.

By the way we can provide different folders, target files, patterns in that `folders` file. This script can observe any folder you put in there, even we can take actions denepding on modified and deleted files. Let's talk.