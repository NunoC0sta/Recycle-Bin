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
# Parameters: $@ - All files/directories being passed to the function
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
    local rel_path=$FILES_DIR

    if [ "$#" -eq 0 ]; then
        echo "Error: No file specified"
        return 1
    fi

    if [ ! -e "$1" ]; then
        echo "Error: '$1' does not exist"
        return 1
    fi

    for file in "$@"; do

        id=$(generate_unique_id)
        name=$(basename "$file")
        path=$(realpath "$file")
        delete_date=$(date "+%Y-%m-%d %H:%M:%S")
        size=$(stat -c %s "$file")
        type=$(basename "$file" | sed 's/.*\.//')
        permissions=$(stat -c %A "$file")
        owner=$(stat -c %U "$file")

        #Checks if the path of the argument currently being utilized by the function is a directory
        if [[ -d "$file" ]]; then
            find "$file" -mindepth 1 | while read -r sub_item; do
            delete_file "$sub_item"
            done
            echo "$id,$name,$path,$delete_date,$size,$type,$permissions,$owner" >> "$METADATA_FILE"
            mv "$file" "$FILES_DIR/$id.$type"
            
        fi
            

        if [ -f "$file" ]; then
            echo "$id,$name,$path,$delete_date,$size,$type,$permissions,$owner" >> "$METADATA_FILE"
            mv "$file" "$FILES_DIR/$id.$type"
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
    echo "=== Recycle Bin Content ==="

    # Verifica se o ficheiro metadata existe e não está vazio
    if [ ! -s "$METADATA_FILE" ]; then
        echo "The Recycle Bin is empty."
        return 0
    fi

    # Lê o ficheiro metadata linha a linha, ignora o cabeçalho
    tail -n +2 "$METADATA_FILE" | while IFS=',' read -r id nome caminho data tamanho tipo permissoes dono; do
        echo "ID: $id"
        echo "Name: $nome"
        echo "Date: $data"
        echo "Size: $tamanho"
        echo "Type: $tipo"
        echo "------------------------------"
    done

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
    # Arguments:
    #   [ids or patterns...] - optional, specify files to delete selectively

    if [ "$#" -eq 0 ]; then
        echo "Delete all items in recycle bin permanently?"
        read -rp "(y/n): " confirm
        case "$confirm" in
            [Yy]*)
                echo "Deleting all files..."
                echo "List of files being deleted:"
                list_recycled
                count=$(find "$FILES_DIR" -type f | wc -l)
                size=$(du -ch "$FILES_DIR" | tail -n 1 | awk '{print $1}')
                rm -rf "$FILES_DIR"/*
                echo "Recycle Bin emptied ($count files, total size $size)."
                # Reset metadata file
                echo "ID,ORIGINAL_NAME,ORIGINAL_PATH,DELETION_DATE,FILE_SIZE,FILE_TYPE,PERMISSIONS,OWNER" > "$METADATA_FILE"
                ;;
            [Nn]*)
                echo "Operation cancelled."
                ;;
            *)
                echo "Invalid input. Please enter y or n."
                ;;
        esac
    elif [ "$#" -gt 0 ]; then
        echo "Delete specified items permanently?"
        read -rp "(y/n): " confirm
        case "$confirm" in
            [Yy]*)
                for pattern in "$@"; do
                    echo "Deleting items matching pattern: $pattern"
                    rm -rf "$FILES_DIR"/$pattern*
                    # Remove matching entries from metadata
                    grep -v "^$pattern" "$METADATA_FILE" > "$METADATA_FILE.tmp"
                    mv "$METADATA_FILE.tmp" "$METADATA_FILE"
                done
                echo "Specified items deleted."
                ;;
            [Nn]*)
                echo "Operation cancelled."
                ;;
            *)
                echo "Invalid input. Please enter y or n."
                ;;
        esac
    else
        echo "Error: Invalid arguments"
        return 1

    fi

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
    # Initialize recycle bin
    initialize_recyclebin
    # Parse command line arguments
    case "$1" in
        delete)
            shift
            delete_file "$@"
            ;;
        list)
            list_recycled
            ;;
        restore)
            restore_file "$2"
            ;;
        search)
            search_recycled "$2"
            ;;
        empty)
            shift
            empty_recyclebin "$@"
            ;;
        help|--help|-h)
            display_help
            ;;
        *)
            echo "Invalid option. Use 'help' for usage information."
            exit 1
            ;;
        esac
}

# Execute main function with all arguments
main "$@"