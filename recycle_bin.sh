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
CONFIG_FILE="$RECYCLE_BIN_DIR/config.cfg"
LOG_FILE="$RECYCLE_BIN_DIR/log.txt"
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
    # Create recycle bin directory if it doesn't exist
    if [ ! -d "$RECYCLE_BIN_DIR" ]; then
        mkdir -p "$RECYCLE_BIN_DIR"
        mkdir -p "$FILES_DIR"

        # Initialize metadata file
        touch "$METADATA_FILE"
        echo "# Recycle Bin Metadata" > "$METADATA_FILE"
        echo "ID,ORIGINAL_NAME,ORIGINAL_PATH,DELETION_DATE,FILE_SIZE,FILE_TYPE,PERMISSIONS,OWNER" >> "$METADATA_FILE"

        # Initialize config file
        touch "$CONFIG_FILE"
        echo "# Recycle Bin Configuration" > "$CONFIG_FILE"
        echo "MAX_SIZE_MB=1024" >> "$CONFIG_FILE"         # default Max Size in MB
        echo "RETENTION_DAYS=30" >> "$CONFIG_FILE"  # default Retention Time Limit until permanent deletion in days

        # Initialize empty log file
        touch "$LOG_FILE"

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
# Description: Moves file/directory to recycle bin with error handling
# Parameters: $@ - All files/directories being passed to the function
# Returns: 0 on success, 1 on failure
#################################################
delete_file() {
    local id name path delete_date size type permissions owner
    local rel_path=$FILES_DIR

    # No arguments
    if [ "$#" -eq 0 ]; then
        echo "Error: No file specified"
        echo "$(date '+%Y-%m-%d %H:%M:%S') | DELETE | ERROR | No file specified" >> "$LOG_FILE"
        return 1
    fi

    for file in "$@"; do
        # Prevent deleting recycle bin itself
        if [[ "$file" == "$RECYCLE_BIN_DIR"* ]]; then
            echo -e "${RED}Error: Cannot delete the recycle bin itself (${file})${NC}"
            echo "$(date '+%Y-%m-%d %H:%M:%S') | DELETE | ERROR | Attempted to delete recycle bin itself: '$file'" >> "$LOG_FILE"
            continue
        fi

        # File doesn't exist
        if [ ! -e "$file" ]; then
            echo -e "${RED}Error: '$file' does not exist${NC}"
            echo "$(date '+%Y-%m-%d %H:%M:%S') | DELETE | ERROR | '$file' does not exist" >> "$LOG_FILE"
            continue
        fi

        # Permission check (read + write)
        if [ ! -r "$file" ] || [ ! -w "$file" ]; then
            echo -e "${RED}Error: No read/write permission for '$file'${NC}"
            echo "$(date '+%Y-%m-%d %H:%M:%S') | DELETE | ERROR | Permission denied for '$file'" >> "$LOG_FILE"
            continue
        fi

        # Get size of the file (for disk space check)
        size=$(du -sk "$file" 2>/dev/null | awk '{print $1}')
        available=$(df -k "$FILES_DIR" | tail -1 | awk '{print $4}')

        if [ "$available" -lt "$size" ]; then
            echo -e "${RED}Error: Insufficient disk space in recycle bin${NC}"
            echo "$(date '+%Y-%m-%d %H:%M:%S') | DELETE | ERROR | Not enough space to move '$file' (needed ${size}KB, available ${available}KB)" >> "$LOG_FILE"
            continue
        fi

        # Gather file info
        id=$(generate_unique_id)
        name=$(basename "$file")
        path=$(realpath "$file")
        delete_date=$(date "+%Y-%m-%d %H:%M:%S")
        type=$(basename "$file" | sed 's/.*\.//')
        permissions=$(stat -c %A "$file")
        owner=$(stat -c %U "$file")

        # Handle directory
        if [[ -d "$file" ]]; then
            find "$file" -mindepth 1 | while read -r sub_item; do
                delete_file "$sub_item"
            done
            echo "$id,$name,$path,$delete_date,$size,DIR,$permissions,$owner" >> "$METADATA_FILE"
            if mv "$file" "$FILES_DIR/$id" 2>/dev/null; then
                echo "$(date '+%Y-%m-%d %H:%M:%S') | DELETE | SUCCESS | Directory '$path' -> ID: $id" >> "$LOG_FILE"
            else
                echo -e "${RED}Error: Failed to move directory '$file'${NC}"
                echo "$(date '+%Y-%m-%d %H:%M:%S') | DELETE | ERROR | Failed to move directory '$file'" >> "$LOG_FILE"
            fi
            continue
        fi

        # Handle file
        if [ -f "$file" ]; then
            echo "$id,$name,$path,$delete_date,$size,$type,$permissions,$owner" >> "$METADATA_FILE"
            if mv "$file" "$FILES_DIR/$id.$type" 2>/dev/null; then
                echo "$(date '+%Y-%m-%d %H:%M:%S') | DELETE | SUCCESS | File '$path' -> ID: $id.$type" >> "$LOG_FILE"
            else
                echo -e "${RED}Error: Failed to move file '$file'${NC}"
                echo "$(date '+%Y-%m-%d %H:%M:%S') | DELETE | ERROR | Failed to move file '$file'" >> "$LOG_FILE"
            fi
        else
            echo -e "${RED}Error: Unknown item type '$file'${NC}"
            echo "$(date '+%Y-%m-%d %H:%M:%S') | DELETE | ERROR | Unknown item type '$file'" >> "$LOG_FILE"
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

    # Check if metadata has any entries beyond the first two lines
    if [ "$(tail -n +3 "$METADATA_FILE" | wc -l)" -eq 0 ]; then
        echo "The Recycle Bin is empty."
        return 0
    fi

    # --- Detailed Mode ---
    if [[ "$1" == "--detailed" ]]; then
        echo "=== Detailed Recycle Bin Content ==="

        # Cabeçalho da tabela
        printf "%-20s %-20s %-10s %-25s %-10s %-10s %-15s %-40s\n" \
            "ID" "NAME" "TYPE" "DELETION_DATE" "SIZE" "PERMS" "OWNER" "ORIGINAL_PATH"
        printf "%0.s-" {1..160}; echo

        # Lê e mostra todos os registos em formato completo
        tail -n +3 "$METADATA_FILE" \
            | sort -t ',' -k2,2 \
            | while IFS=',' read -r id name path date size type perms owner; do
                # Converte tamanho para formato legível (se disponível)
                if command -v numfmt >/dev/null 2>&1; then
                    size_h=$(numfmt --to=iec --suffix=B "$size" 2>/dev/null || echo "$size B")
                else
                    size_h="$size B"
                fi

                printf "%-20s %-20s %-10s %-25s %-10s %-10s %-15s %-40s\n" \
                    "$id" "$name" "$type" "$date" "$size_h" "$perms" "$owner" "$path"
            
            done



        echo
        echo "Detailed mode enabled"
        return 0
    fi
    # --- Fim do Detailed Mode ---


    # Determina o critério de ordenação (por defeito: name)
    local sort_by="name"
    if [[ "$1" == "--sort" && -n "$2" ]]; then
        case "$2" in
            name|date|size) sort_by="$2" ;;
            *)
                echo -e "${RED}Invalid sort option. Use: name, date or size.${NC}"
                return 1
                ;;
        esac
    fi

    # Escolhe o campo de ordenação (coluna correspondente)
    # 1:ID 2:NAME 3:PATH 4:DATE 5:SIZE 6:TYPE 7:PERMS 8:OWNER
    local sort_col
    case "$sort_by" in
        name) sort_col=2 ;;
        date) sort_col=4 ;;
        size) sort_col=5 ;;
    esac

    # Imprime o cabeçalho da tabela
    printf "%-20s %-15s %-10s %-25s %-10s %-15s %-10s %-10s\n" \
        "ID" "NAME" "TYPE" "DELETION_DATE" "SIZE" "PERMS" "OWNER" "PATH"
    printf "%0.s-" {1..140}; echo

    # Lê o ficheiro metadata (sem o cabeçalho) e ordena conforme a flag
    tail -n +3 "$METADATA_FILE" \
        | sort -t ',' -k"$sort_col","$sort_col" \
        | while IFS=',' read -r id name path date size type perms owner; do
            printf "%-20s %-15s %-10s %-25s %-10s %-15s %-10s %-10s\n" \
                "$id" "$name" "$type" "$date" "$size" "$perms" "$owner" "$path"
        done

    echo
    echo "Sorted by: $sort_by"
    return 0
}



#################################################
# Function: restore_file
# Description: Restores file from recycle bin
# Parameters: $1 - unique ID of file to restore
# Returns: 0 on success, 1 on failure
#################################################
restore_file() {
    local input="$1"

    if [ -z "$input" ]; then
        echo -e "${RED}Error: No file ID or filename specified${NC}"
        echo "$(date '+%Y-%m-%d %H:%M:%S') | RESTORE | ERROR | No file ID or name specified" >> "$LOG_FILE"
        return 1
    fi

    # Try to find a match by ID first
    local metadata
    metadata=$(grep "^$input," "$METADATA_FILE")

    # If not found by ID, try to find by filename (case-insensitive)
    if [ -z "$metadata" ]; then
        metadata=$(awk -F',' -v name="$input" 'tolower($2) == tolower(name) {print; exit}' "$METADATA_FILE")
    fi

    if [ -z "$metadata" ]; then
        echo -e "${RED}Error: No file found with ID or name '$input'${NC}"
        echo "$(date '+%Y-%m-%d %H:%M:%S') | RESTORE | ERROR | No file found for ID or name '$input'" >> "$LOG_FILE"
        return 1
    fi

    # Split metadata fields
    IFS=',' read -r id name original_path deletion_date size type perms owner <<< "$metadata"

    # Prevent restoring into recycle bin itself
    if [[ "$original_path" == "$RECYCLE_BIN_DIR"* ]]; then
        echo -e "${RED}Error: Cannot restore inside recycle bin itself${NC}"
        echo "$(date '+%Y-%m-%d %H:%M:%S') | RESTORE | ERROR | Attempt to restore inside recycle bin -> ID: $id" >> "$LOG_FILE"
        return 1
    fi

    # Restoration process for directories
    if [[ "$type" == "DIR" ]]; then
        # Check disk space before merge or move
        required_space=$(du -s "$FILES_DIR/$id" | awk '{print $1}') # KB
        avail_space=$(df -k "$(dirname "$original_path")" | tail -1 | awk '{print $4}') # KB
        if [ "$avail_space" -lt "$required_space" ]; then
            echo -e "${RED}Error: Insufficient disk space to restore '$original_path'${NC}"
            echo "$(date '+%Y-%m-%d %H:%M:%S') | RESTORE | ERROR | Insufficient disk space for directory '$original_path' -> ID: $id" >> "$LOG_FILE"
            return 1
        fi

        if [ -d "$original_path" ]; then
            if ! rsync -a "$FILES_DIR/$id/" "$original_path/" 2>/dev/null; then
                echo -e "${RED}Error: Permission denied while merging directory '$original_path'${NC}"
                echo "$(date '+%Y-%m-%d %H:%M:%S') | RESTORE | ERROR | Permission denied for '$original_path' -> ID: $id" >> "$LOG_FILE"
                return 1
            fi
            rm -rf "$FILES_DIR/$id"
            echo "Directory restored (merged): $original_path"
            echo "$(date '+%Y-%m-%d %H:%M:%S') | RESTORE | MERGED | Directory '$original_path' -> ID: $id" >> "$LOG_FILE"
        else
            if ! mv "$FILES_DIR/$id" "$original_path" 2>/dev/null; then
                echo -e "${RED}Error: Permission denied while restoring directory '$original_path'${NC}"
                echo "$(date '+%Y-%m-%d %H:%M:%S') | RESTORE | ERROR | Permission denied for '$original_path' -> ID: $id" >> "$LOG_FILE"
                return 1
            fi
            echo "Directory restored: $original_path"
            echo "$(date '+%Y-%m-%d %H:%M:%S') | RESTORE | SUCCESS | Directory '$original_path' -> ID: $id" >> "$LOG_FILE"
        fi
    else
        # Restoration process for files
        # Ensure parent directory exists
        if ! mkdir -p "$(dirname "$original_path")" 2>/dev/null; then
            echo -e "${RED}Error: Cannot create parent directory for '$original_path' (permission denied)${NC}"
            echo "$(date '+%Y-%m-%d %H:%M:%S') | RESTORE | ERROR | Cannot create parent directory for '$original_path' -> ID: $id" >> "$LOG_FILE"
            return 1
        fi

        recycle_path="$FILES_DIR/$id.$type"

        #Error Handling in the case of the file not existing inside the recycle b
        if [ ! -e "$recycle_path" ]; then
            echo -e "${YELLOW}Warning: File not found in recycle bin: $recycle_path${NC}"
            echo "$(date '+%Y-%m-%d %H:%M:%S') | RESTORE | ERROR | File missing: '$recycle_path' -> ID: $id" >> "$LOG_FILE"
            return 1
        fi

        # Error Handling in case of insuficient disk space
        required_space=$(du -k "$recycle_path" | awk '{print $1}')
        avail_space=$(df -k "$(dirname "$original_path")" | tail -1 | awk '{print $4}')
        if [ "$avail_space" -lt "$required_space" ]; then
            echo -e "${RED}Error: Insufficient disk space to restore '$original_path'${NC}"
            echo "$(date '+%Y-%m-%d %H:%M:%S') | RESTORE | ERROR | Insufficient disk space for '$original_path' -> ID: $id" >> "$LOG_FILE"
            return 1
        fi

        # Handle conflicts
        if [ -e "$original_path" ]; then
            echo -e "${YELLOW}Warning: File already exists at original location: $original_path${NC}"
            echo "Choose action: [O]verwrite / [R]estore with modified name / [C]ancel"
            read -rp "(O/R/C): " choice
            case "$choice" in
                [Oo]*)
                    if ! mv -f "$recycle_path" "$original_path" 2>/dev/null; then
                        echo -e "${RED}Error: Permission denied while overwriting '$original_path'${NC}"
                        echo "$(date '+%Y-%m-%d %H:%M:%S') | RESTORE | ERROR | Permission denied for '$original_path' -> ID: $id" >> "$LOG_FILE"
                        return 1
                    fi
                    echo "File restored (overwritten): $original_path"
                    echo "$(date '+%Y-%m-%d %H:%M:%S') | RESTORE | OVERWRITE | File '$original_path' -> ID: $id" >> "$LOG_FILE"
                    ;;
                [Rr]*)
                    timestamp=$(date "+%Y%m%d%H%M%S")
                    new_name="${original_path%.*}_$timestamp.${type}"
                    if ! mv "$recycle_path" "$new_name" 2>/dev/null; then
                        echo -e "${RED}Error: Permission denied while restoring with new name '$new_name'${NC}"
                        echo "$(date '+%Y-%m-%d %H:%M:%S') | RESTORE | ERROR | Permission denied for '$new_name' -> ID: $id" >> "$LOG_FILE"
                        return 1
                    fi
                    echo "File restored with new name: $new_name"
                    echo "$(date '+%Y-%m-%d %H:%M:%S') | RESTORE | RENAMED | File '$new_name' -> ID: $id" >> "$LOG_FILE"
                    original_path="$new_name"
                    ;;
                [Cc]*)
                    echo "Restore cancelled for $original_path"
                    echo "$(date '+%Y-%m-%d %H:%M:%S') | RESTORE | CANCEL | File '$original_path' -> ID: $id" >> "$LOG_FILE"
                    return 0
                    ;;
                *)
                    echo "Invalid choice. Skipping $original_path"
                    echo "$(date '+%Y-%m-%d %H:%M:%S') | RESTORE | CANCEL | File '$original_path' -> ID: $id" >> "$LOG_FILE"
                    return 0
                    ;;
            esac
        else
            if ! mv "$recycle_path" "$original_path" 2>/dev/null; then
                echo -e "${RED}Error: Permission denied while restoring '$original_path'${NC}"
                echo "$(date '+%Y-%m-%d %H:%M:%S') | RESTORE | ERROR | Permission denied for '$original_path' -> ID: $id" >> "$LOG_FILE"
                return 1
            fi
            echo "File restored: $original_path"
            echo "$(date '+%Y-%m-%d %H:%M:%S') | RESTORE | SUCCESS | File '$original_path' -> ID: $id" >> "$LOG_FILE"
        fi

        # Restore permissions
        perm_bits="${perms#-}"
        owner_bits=0; group_bits=0; other_bits=0
        [[ ${perm_bits:0:1} == "r" ]] && ((owner_bits+=4))
        [[ ${perm_bits:1:1} == "w" ]] && ((owner_bits+=2))
        [[ ${perm_bits:2:1} == "x" ]] && ((owner_bits+=1))
        [[ ${perm_bits:3:1} == "r" ]] && ((group_bits+=4))
        [[ ${perm_bits:4:1} == "w" ]] && ((group_bits+=2))
        [[ ${perm_bits:5:1} == "x" ]] && ((group_bits+=1))
        [[ ${perm_bits:6:1} == "r" ]] && ((other_bits+=4))
        [[ ${perm_bits:7:1} == "w" ]] && ((other_bits+=2))
        [[ ${perm_bits:8:1} == "x" ]] && ((other_bits+=1))

        num_permissions="${owner_bits}${group_bits}${other_bits}"
        chmod "$num_permissions" "$original_path"
        echo "Permissions restored: $perms ($num_permissions)"
    fi

    # Remove entry from metadata
    grep -v "^$id," "$METADATA_FILE" > "$METADATA_FILE.tmp" && mv "$METADATA_FILE.tmp" "$METADATA_FILE"

    return 0
}




#################################################
# Function: empty_recyclebin
# Description: Permanently deletes all items
# Parameters: None
# Returns: 0 on success
#################################################
empty_recyclebin() {
    # Use AUTO_CONFIRM env var (expected values: "true" or "false")
    local auto_confirm="${AUTO_CONFIRM:-false}"

    # If stdin is not a terminal, assume non-interactive; allow auto confirm
    local noninteractive=false
    if [ ! -t 0 ]; then
        noninteractive=true
    fi

    # if there are not arguments empty the entire recycle bin
    if [ "$#" -eq 0 ]; then
        echo "Delete all items in recycle bin permanently?"

        #Auto Confirm so the Test can run without user interaction, if ran manually it will ask for confirmation
        if [ "$auto_confirm" = true ]; then
            confirm="y"
        else
            read -rp "(y/n): " confirm
        fi

        case "$confirm" in
            [Yy]*)
                #Shows the List of files being deleted
                echo "Deleting all files..."
                echo "List of files being deleted:"
                list_recycled

                # Get count and size before deletion
                count=$(find "$FILES_DIR" -type f | wc -l)
                size=$(du -ch "$FILES_DIR" | tail -n 1 | awk '{print $1}')
                # Deletion of all files and directories inside the files directory
                rm -rf "$FILES_DIR"/*
                echo "Recycle Bin emptied ($count files, total size $size)."
                # Reset metadata file
                echo "# Recycle Bin Metadata" > "$METADATA_FILE"
                echo "ID,ORIGINAL_NAME,ORIGINAL_PATH,DELETION_DATE,FILE_SIZE,FILE_TYPE,PERMISSIONS,OWNER" >> "$METADATA_FILE"
                ;;
            [Nn]*)
                echo "Operation cancelled."
                ;;
            *)
                echo "Invalid input. Please enter y or n."
                ;;
        esac

    # If arguments are given delete only specified items
    else
        echo "Delete specified items permanently?"
        read -rp "(y/n): " confirm
        case "$confirm" in
            [Yy]*)
                for key in "$@"; do
                    # Try to find by ID first
                    match=$(grep "^$key," "$METADATA_FILE")
                    
                    # If not found, try searching by OriginalName
                    if [ -z "$match" ]; then
                        match=$(awk -F',' -v name="$key" '$2==name {print $0}' "$METADATA_FILE")
                    fi

                    if [ -z "$match" ]; then
                        echo "No metadata found for ID or name: $key"
                        continue
                    fi

                    # Extract ID and type
                    id=$(echo "$match" | cut -d',' -f1)
                    type=$(echo "$match" | cut -d',' -f6)
                    file_path="$FILES_DIR/$id.$type"

                    if [ -e "$file_path" ]; then
                        echo "Deleting $file_path permanently..."
                        rm -rf "$file_path"
                    else
                        echo "File not found in recycle bin: $file_path"
                    fi

                    # Remove the metadata line
                    grep -v "^$id," "$METADATA_FILE" > "$METADATA_FILE.tmp"
                    mv "$METADATA_FILE.tmp" "$METADATA_FILE"
                done
                echo "Specified items permanently deleted."
                ;;
            [Nn]*)
                echo "Operation cancelled."
                ;;
            *)
                echo "Invalid input. Please enter y or n."
                ;;
        esac
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
    # --- Search by date range ---
    if [ "$1" = "date" ]; then
        local start_date="$2"
        local end_date="$3"

        if [ -z "$start_date" ] || [ -z "$end_date" ]; then
            echo -e "${RED}Error: Please provide start and end dates${NC}"
            echo "Usage: $0 search date 'YYYY-MM-DD HH:MM:SS' 'YYYY-MM-DD HH:MM:SS'"
            return 1
        fi

        echo "Results for deletion dates between '$start_date' and '$end_date':"
        local start_ts end_ts file_ts results_found=0

        start_ts=$(date -d "$start_date" +%s 2>/dev/null)
        end_ts=$(date -d "$end_date" +%s 2>/dev/null)
        if [ -z "$start_ts" ] || [ -z "$end_ts" ]; then
            echo -e "${RED}Error: Invalid date format.${NC}"
            echo "Use format: YYYY-MM-DD HH:MM:SS"
            return 1
        fi

        # Cabeçalho da tabela
        printf "%-20s %-20s %-10s %-25s %-10s %-10s %-15s %-40s\n" \
            "ID" "NAME" "TYPE" "DELETION_DATE" "SIZE" "PERMS" "OWNER" "ORIGINAL_PATH"
        printf "%0.s-" {1..160}; echo

        tail -n +3 "$METADATA_FILE" | while IFS=',' read -r id name path date size type perms owner; do
            file_ts=$(date -d "$date" +%s 2>/dev/null)
            if [ "$file_ts" -ge "$start_ts" ] && [ "$file_ts" -le "$end_ts" ]; then
                if command -v numfmt >/dev/null 2>&1; then
                    size_h=$(numfmt --to=iec --suffix=B "$size" 2>/dev/null || echo "$size B")
                else
                    size_h="$size B"
                fi

                printf "%-20s %-20s %-10s %-25s %-10s %-10s %-15s %-40s\n" \
                    "$id" "$name" "$type" "$date" "$size_h" "$perms" "$owner" "$path"
                results_found=1
            fi
        done

        if [ "$results_found" -eq 0 ]; then
            echo "No results found."
        fi
        return 0
    fi

    # --- Search by pattern or type ---
    local pattern="$1"
    if [ -z "$pattern" ]; then
        echo -e "${RED}Error: No search pattern specified${NC}"
        echo "Usage: $0 search <pattern> OR $0 search date <start> <end>"
        return 1
    fi

    echo "Results for pattern '$pattern':"
    local results_found=0

    # Cabeçalho da tabela
    printf "%-20s %-20s %-10s %-25s %-10s %-10s %-15s %-40s\n" \
        "ID" "NAME" "TYPE" "DELETION_DATE" "SIZE" "PERMS" "OWNER" "ORIGINAL_PATH"
    printf "%0.s-" {1..160}; echo

    tail -n +3 "$METADATA_FILE" | while IFS=',' read -r id name path date size type perms owner; do
        # Pesquisa no nome, path e tipo (extensão)
        if echo "$name,$path,$type" | grep -Eiq "$pattern"; then
            if command -v numfmt >/dev/null 2>&1; then
                size_h=$(numfmt --to=iec --suffix=B "$size" 2>/dev/null || echo "$size B")
            else
                size_h="$size B"
            fi

            printf "%-20s %-20s %-10s %-25s %-10s %-10s %-15s %-40s\n" \
                "$id" "$name" "$type" "$date" "$size_h" "$perms" "$owner" "$path"
            results_found=1
        fi
    done

    if [ "$results_found" -eq 0 ]; then
        echo "No results found."
    fi

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
            shift
            search_recycled "$@"
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


show_statistics() {
    # Verifica se há itens na recycle bin
    if [ "$(tail -n +3 "$METADATA_FILE" | wc -l)" -eq 0 ]; then
        echo "The Recycle Bin is empty."
        return 0
    fi

    total_items=$(tail -n +3 "$METADATA_FILE" | wc -l)
    total_size_bytes=$(tail -n +3 "$METADATA_FILE" | awk -F',' '{sum+=$5} END{print sum}')

    # Calcula total em formato legível
    if [ "$total_size_bytes" -ge 1073741824 ]; then

    # O valor 1073741824 segundo o chatgot vem da expressão 1GB=1024MB×1024KB×1024B=1073741824B
        total_size=$(echo "scale=2; $total_size_bytes/1073741824" | bc)GB
    elif [ "$total_size_bytes" -ge 1048576 ]; then
        total_size=$(echo "scale=2; $total_size_bytes/1048576" | bc)MB
    elif [ "$total_size_bytes" -ge 1024 ]; then
        total_size=$(echo "scale=2; $total_size_bytes/1024" | bc)KB
    else
        total_size="${total_size_bytes}B"
    fi

    # Tipo de arquivo
    files_count=$(tail -n +3 "$METADATA_FILE" | awk -F',' '$6 != "directory" {count++} END{print count+0}')
    dirs_count=$(tail -n +3 "$METADATA_FILE" | awk -F',' '$6 == "directory" {count++} END{print count+0}')

    # Data mais antiga e mais recente
    oldest_date=$(tail -n +3 "$METADATA_FILE" | sort -t',' -k4 | head -n1 | awk -F',' '{print $4}')
    newest_date=$(tail -n +3 "$METADATA_FILE" | sort -t',' -k4 | tail -n1 | awk -F',' '{print $4}')

    # Tamanho médio
    avg_size=$(tail -n +3 "$METADATA_FILE" | awk -F',' '{sum+=$5; count++} END{if(count>0) printf "%.2f", sum/count; else print 0}')

    echo "=== Recycle Bin Statistics ==="
    echo "Total items      : $total_items"
    echo "Total size       : $total_size bytes"
    echo "Files            : $files_count"
    echo "Directories      : $dirs_count"
    echo "Oldest item      : $oldest_date"
    echo "Newest item      : $newest_date"
    echo "Average file size: $avg_size bytes"
    echo "=============================="
    return 0
}


# Execute main function with all arguments
main "$@"