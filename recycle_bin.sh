#!/bin/bash

RECYCLE_BIN_DIR="$HOME/.recycle_bin"
METADATA_FILE="$RECYCLE_BIN_DIR/metadata.db"

function initialize_recyclebin() 
{
	local r_bin_path="$HOME/.recycle_bin/"
	local files_path="$HOME/.recycle_bin/files"
	local config_path="$HOME/.recycle_bin/config.txt"
	local log_path="$HOME/.recycle_bin/recyclebin.log"

	if [ -d $r_bin_path ]; then
		echo "Directory $r_bin_path Already Exists"
	else
		mkdir -p $r_bin_path
		echo "Directory $r_bin_path created."
	fi

	if [ -d $files_path ]; then
		echo "Directory $files_path Already Exists"
	else
		mkdir -p $files_path
		echo "Directory $files_path created."
	fi

	if [ -f $METADATA_FILE ]; then
        echo "Metadata file $METADATA_FILE already exists."
    else
        echo "ID,ORIGINAL_NAME,ORIGINAL_PATH,DELETION_DATE,FILE_SIZE,FILE_TYPE,PERMISSIONS,OWNER" > "$METADATA_FILE"
        echo "Metadata file $METADATA_FILE created with CSV header."
    fi

	if [ -f $config_path ]; then
        echo "Config file $config_path already exists."
    else
        echo -e "MAX_SIZE_MB=1024\nRETENTION_DAYS=30" > $config_path
        echo "Config file $config_path created with default settings."
    fi

	if [ -f $log_path ]; then
        echo "log file $log_path already exists."
    else
        touch $log_path
		echo "Log file $log_path created."
    fi
	
}

main() {
	echo "Hello, Recycle Bin!"
	initialize_recyclebin
}
main "$@"
