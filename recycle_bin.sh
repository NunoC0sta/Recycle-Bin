#!/bin/bash

#################################################
# Linux Recycle Bin Simulation
# Author: [Your Name]
# Date: [Date]
# Description: Shell-based recycle bin system
#################################################
# Global Configuration
RECYCLE_BIN_DIR="$HOME/.recycle_bin"
FILES_DIR="$RECYCLE_BIN_DIR/files"
METADATA_FILE="$RECYCLE_BIN_DIR/metadata.db"
CONFIG_FILE="$RECYCLE_BIN_DIR/config"
# Color codes for output (optional)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color


#################################################
# Function: initialize_recyclebin
# Description: Creates recycle bin directory structure
# Parameters: None
# Returns: 0 on success, 1 on failure
#################################################
initialize_recyclebin() {
if [ ! -d "$RECYCLE_BIN_DIR" ]; then
mkdir -p "$FILES_DIR"
touch "$METADATA_FILE"
echo "# Recycle Bin Metadata" > "$METADATA_FILE"
echo "ID,ORIGINAL_NAME,ORIGINAL_PATH,DELE-
TION_DATE,FILE_SIZE,FILE_TYPE,PERMISSIONS,OWNER" >> "$METADATA_FILE"
echo "Recycle bin initialized at $RECYCLE_BIN_DIR"
return 0
fi
return 0
}


#################################################
# Function: generate_unique_id
# Description: Generates unique ID for deleted files
# Parameters: None
# Returns: Prints unique ID to stdout
#################################################
generate_unique_id() {
local timestamp=$(date +%s)
local random=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 6 | head -n 1)
echo "${timestamp}_${random}"
}


#################################################
# Function: delete_file
# Description: Moves file/directory to recycle bin
# Parameters: $1 - path to file/directory
# Returns: 0 on success, 1 on failure
#################################################
delete_file() {
	local id
	local name
	local path
	local delete_date
	local size 
	local type 
	local permissions 
	local owner

	for file in "$@"; do

		if [ -z "$file" ]; then
			echo -e "${RED}Error: No file specified${NC}"
			return 1
		fi
		# Check if file exists
		if [ ! -e "$file" ]; then
			echo -e "${RED}Error: File '$file' does not exist${NC}"
			return 1
		fi

		if [ -e "$file" ]; then
			id=$(generate_unique_id)
			name=$(basename $file)
			path=$(realpath $file)
			delete_date=$(date +"%d-%m-%Y")
			size=$(stat -c %s "$file")
            type=$(file --brief "$file")
            permissions=$(stat -c %A "$file")
            owner=$(stat -c %U "$file")
			echo -n "$id,$name,$path,$delete_date,$size$type,$permissions,$owner" >> $METADATA_FILE
			mv "$file" "$FILES_DIR/$id"
			echo "Delete function called with: $file"
        fi
	done
	
	return 0
}


#################################################
# Function: list_recycled
# Description: Lists all items in recycle bin
# Parameters: None
# Returns: 0 on success
#################################################
list_recycled() {
# TODO: Implement this function
echo "=== Recycle Bin Contents ==="
# Your code here
# Hint: Read metadata file and format output
# Hint: Use printf for formatted table
# Hint: Skip header line
return 0
}


#################################################
# Function: restore_file
# Description: Restores file from recycle bin
# Parameters: $1 - unique ID of file to restore
# Returns: 0 on success, 1 on failure
#################################################
restore_file() {
# TODO: Implement this function
local file_id="$1"
if [ -z "$file_id" ]; then
echo -e "${RED}Error: No file ID specified${NC}"
return 1
fi
# Your code here
# Hint: Search metadata for matching ID
# Hint: Get original path from metadata
# Hint: Check if original path exists
# Hint: Move file back and restore permissions
# Hint: Remove entry from metadata
return 0
}


#################################################
# Function: empty_recyclebin
# Description: Permanently deletes all items
# Parameters: None
# Returns: 0 on success
#################################################
empty_recyclebin() {
# TODO: Implement this function
# Your code here
# Hint: Ask for confirmation
# Hint: Delete all files in FILES_DIR
# Hint: Reset metadata file
return 0
}


#################################################
# Function: search_recycled
# Description: Searches for files in recycle bin
# Parameters: $1 - search pattern
# Returns: 0 on success
#################################################
search_recycled() {
# TODO: Implement this function
local pattern="$1"
# Your code here
# Hint: Use grep to search metadata
return 0
}


#################################################
# Function: display_help
# Description: Shows usage information
# Parameters: None
# Returns: 0
#################################################
display_help() {
cat << EOF
Linux Recycle Bin - Usage Guide
SYNOPSIS:
$0 [OPTION] [ARGUMENTS]
OPTIONS:
delete <file> Move file/directory to recycle bin
list List all items in recycle bin
restore <id> Restore file by ID
search <pattern> Search for files by name
empty Empty recycle bin permanently
help Display this help message
EXAMPLES:
$0 delete myfile.txt
$0 list
$0 restore 1696234567_abc123
$0 search "*.pdf"
$0 empty
EOF
return 0
}


#################################################
# Function: main
# Description: Main program logic
# Parameters: Command line arguments
# Returns: Exit code
#################################################
main() {
	initialize_recyclebin
	generate_unique_id
	delete_file /home/nuno/asdasdasdas.txt
}
main "$@"