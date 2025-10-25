#!/bin/bash
# Comprehensive Test Suite for Linux Recycle Bin
SCRIPT="./recycle_bin.sh"
TEST_DIR="test_data"
PASS=0
FAIL=0

# Auto Confirm for empty recycle bin tests
export AUTO_CONFIRM="true"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Helper Functions
setup() {
    rm -rf ~/.recycle_bin
    mkdir -p "$TEST_DIR"
}
teardown() {
    rm -rf "$TEST_DIR"
    rm -rf ~/.recycle_bin
}
assert_success() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: $1"
        ((PASS++))
    else
        echo -e "${RED}✗ FAIL${NC}: $1"
        ((FAIL++))
    fi
}
assert_fail() {
    if [ $? -ne 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: $1"
        ((PASS++))
    else
        echo -e "${RED}✗ FAIL${NC}: $1"
        ((FAIL++))
    fi
}

# Utility to create large file
create_large_file() {
    local path="$1"
    local size_mb="$2"
    dd if=/dev/zero of="$path" bs=1M count="$size_mb" &>/dev/null
}

# ============================
# Basic Functionality Tests
# ============================
test_initialization() {
    echo "=== Test: Initialization ==="
    setup
    $SCRIPT help > /dev/null
    assert_success "Initialize recycle bin"
    [ -d ~/.recycle_bin ] && echo "✓ Directory created"
    [ -f ~/.recycle_bin/metadata.db ] && echo "✓ Metadata file created"
}

test_delete_single_file() {
    echo "=== Test: Delete Single File ==="
    setup
    echo "test" > "$TEST_DIR/file1.txt"
    $SCRIPT delete "$TEST_DIR/file1.txt"
    assert_success "Delete single file"
    [ ! -f "$TEST_DIR/file1.txt" ] && echo "✓ File removed from original location"
}

test_delete_multiple_files() {
    echo "=== Test: Delete Multiple Files ==="
    setup
    echo "a" > "$TEST_DIR/file2.txt"
    echo "b" > "$TEST_DIR/file3.txt"
    $SCRIPT delete "$TEST_DIR/file2.txt" "$TEST_DIR/file3.txt"
    assert_success "Delete multiple files"
    [ ! -f "$TEST_DIR/file2.txt" ] && [ ! -f "$TEST_DIR/file3.txt" ] && echo "✓ Files removed"
}

test_delete_empty_dir() {
    echo "=== Test: Delete Empty Directory ==="
    setup
    mkdir "$TEST_DIR/empty_dir"
    $SCRIPT delete "$TEST_DIR/empty_dir"
    assert_success "Delete empty directory"
    [ ! -d "$TEST_DIR/empty_dir" ] && echo "✓ Directory removed"
}

test_delete_dir_with_contents() {
    echo "=== Test: Delete Directory with Contents ==="
    setup
    mkdir -p "$TEST_DIR/dir_with_files"
    echo "x" > "$TEST_DIR/dir_with_files/filea.txt"
    echo "y" > "$TEST_DIR/dir_with_files/fileb.txt"
    $SCRIPT delete "$TEST_DIR/dir_with_files"
    assert_success "Delete directory recursively"
    [ ! -d "$TEST_DIR/dir_with_files" ] && echo "✓ Directory and contents removed"
}

test_list_empty() {
    echo "=== Test: List Empty Bin ==="
    setup
    $SCRIPT list | grep -q "empty"
    assert_success "List empty recycle bin"
}

test_list_with_items() {
    echo "=== Test: List Bin With Items ==="
    setup
    echo "data" > "$TEST_DIR/list_file.txt"
    $SCRIPT delete "$TEST_DIR/list_file.txt"
    $SCRIPT list | grep -q "list_file.txt"
    assert_success "List recycle bin with items"
}

test_restore_file() {
    echo "=== Test: Restore Single File ==="
    setup
    echo "restore" > "$TEST_DIR/restore1.txt"
    $SCRIPT delete "$TEST_DIR/restore1.txt"
    ID=$($SCRIPT list | grep "restore1.txt" | awk '{print $1}')
    $SCRIPT restore "$ID"
    assert_success "Restore file"
    [ -f "$TEST_DIR/restore1.txt" ] && echo "✓ File restored"
}

test_restore_nonexistent_path() {
    echo "=== Test: Restore to Non-existent Path ==="
    setup
    echo "restore" > "$TEST_DIR/fileX.txt"
    $SCRIPT delete "$TEST_DIR/fileX.txt"
    ID=$($SCRIPT list | grep "fileX.txt" | awk '{print $1}')
    rm -r "$TEST_DIR" # remove the original folder
    $SCRIPT restore "$ID"
    assert_fail "Restore when original directory doesn't exist"
}

test_empty_recyclebin() {
    echo "=== Test: Empty Recycle Bin ==="
    setup
    echo "data" > "$TEST_DIR/file_empty.txt"
    $SCRIPT delete "$TEST_DIR/file_empty.txt"
    $SCRIPT empty
    assert_success "Empty entire recycle bin"
}

test_search_existing_file() {
    echo "=== Test: Search Existing File ==="
    setup
    echo "data" > "$TEST_DIR/search1.txt"
    $SCRIPT delete "$TEST_DIR/search1.txt"
    $SCRIPT search "search1.txt" | grep -q "search1.txt"
    assert_success "Search for existing file"
}

test_search_nonexistent_file() {
    echo "=== Test: Search Non-existent File ==="
    setup
    $SCRIPT search "no_file.txt" | grep -q "No results found"
    assert_success "Search for non-existent file"
}

test_display_help() {
    echo "=== Test: Display Help ==="
    $SCRIPT help | grep -q "Usage Guide"
    assert_success "Display help information"
}

# ============================
# Edge Cases
# ============================
test_delete_nonexistent_file() {
    echo "=== Test: Delete Non-existent File ==="
    $SCRIPT delete "fake_file.txt" &>/dev/null
    assert_fail "Delete non-existent file"
}

test_delete_no_permissions() {
    echo "=== Test: Delete File Without Permissions ==="
    setup
    echo "locked" > "$TEST_DIR/locked.txt"
    chmod 000 "$TEST_DIR/locked.txt"
    $SCRIPT delete "$TEST_DIR/locked.txt" &>/dev/null
    assert_fail "Delete file without read/write permissions"
    chmod 644 "$TEST_DIR/locked.txt"
}

test_restore_existing_filename() {
    echo "=== Test: Restore with Filename Conflict ==="
    setup
    echo "orig" > "$TEST_DIR/conflict.txt"
    $SCRIPT delete "$TEST_DIR/conflict.txt"
    echo "new" > "$TEST_DIR/conflict.txt"
    ID=$($SCRIPT list | grep "conflict.txt" | awk '{print $1}')
    echo "O" | $SCRIPT restore "$ID"
    assert_success "Restore with existing filename (overwrite)"
}

test_restore_invalid_id() {
    echo "=== Test: Restore Invalid ID ==="
    $SCRIPT restore "999999999_invalid" &>/dev/null
    assert_fail "Restore with non-existent ID"
}

test_handle_spaces_special_chars() {
    echo "=== Test: Handle Spaces & Special Characters ==="
    setup
    echo "data" > "$TEST_DIR/file with spaces !@#.txt"
    $SCRIPT delete "$TEST_DIR/file with spaces !@#.txt"
    ID=$($SCRIPT list | grep "file with spaces" | awk '{print $1}')
    $SCRIPT restore "$ID"
    assert_success "File with spaces and special characters restored"
}

test_long_filename() {
    echo "=== Test: Handle Very Long Filename ==="
    setup
    LONG_NAME=$(printf 'a%.0s' {1..260})
    echo "data" > "$TEST_DIR/$LONG_NAME.txt"
    $SCRIPT delete "$TEST_DIR/$LONG_NAME.txt"
    ID=$($SCRIPT list | grep "${LONG_NAME}" | awk '{print $1}')
    $SCRIPT restore "$ID"
    assert_success "Very long filename restored"
}

test_large_file() {
    echo "=== Test: Handle Large File ==="
    setup
    create_large_file "$TEST_DIR/largefile.bin" 101
    $SCRIPT delete "$TEST_DIR/largefile.bin"
    ID=$($SCRIPT list | grep "largefile.bin" | awk '{print $1}')
    $SCRIPT restore "$ID"
    assert_success "Large file restored"
}

test_symlink() {
    echo "=== Test: Handle Symbolic Links ==="
    setup
    echo "target" > "$TEST_DIR/target.txt"
    ln -s "$TEST_DIR/target.txt" "$TEST_DIR/symlink.txt"
    $SCRIPT delete "$TEST_DIR/symlink.txt"
    ID=$($SCRIPT list | grep "symlink.txt" | awk '{print $1}')
    $SCRIPT restore "$ID"
    assert_success "Symbolic link restored"
}

test_hidden_file() {
    echo "=== Test: Handle Hidden File ==="
    setup
    echo "secret" > "$TEST_DIR/.hiddenfile"
    $SCRIPT delete "$TEST_DIR/.hiddenfile"
    ID=$($SCRIPT list | grep ".hiddenfile" | awk '{print $1}')
    $SCRIPT restore "$ID"
    assert_success "Hidden file restored"
}

# ============================
# Error Handling
# ============================
test_invalid_args() {
    echo "=== Test: Invalid Command Line ==="
    $SCRIPT nonsense &>/dev/null
    assert_fail "Invalid command line arguments"
}

test_missing_params() {
    echo "=== Test: Missing Required Parameters ==="
    $SCRIPT delete &>/dev/null
    assert_fail "Missing required parameters"
}

test_corrupted_metadata() {
    echo "=== Test: Corrupted Metadata File ==="
    setup
    echo "corrupted content" > ~/.recycle_bin/metadata.db
    $SCRIPT list &>/dev/null
    assert_fail "Handle corrupted metadata file"
}

test_insufficient_space() {
    echo "=== Test: Insufficient Disk Space ==="
    # Simulate by creating a large file
    setup
    create_large_file "$TEST_DIR/hugefile.bin" 10240
    $SCRIPT delete "$TEST_DIR/hugefile.bin"
    # Restore should fail if filesystem too small (manual verification)
    assert_success "Simulated large file deletion"
}

test_permission_denied() {
    echo "=== Test: Restore to Read-only Directory ==="
    setup
    mkdir -p "$TEST_DIR/readonly_dir"
    chmod 555 "$TEST_DIR/readonly_dir"
    echo "data" > "$TEST_DIR/readonly_dir/file.txt"
    $SCRIPT delete "$TEST_DIR/readonly_dir/file.txt"
    ID=$($SCRIPT list | grep "file.txt" | awk '{print $1}')
    $SCRIPT restore "$ID" &>/dev/null
    assert_fail "Restore into read-only directory"
    chmod 755 "$TEST_DIR/readonly_dir"
}

# ============================
# Performance Tests
# ============================
test_delete_many_files() {
    echo "=== Test: Delete 100+ Files ==="
    setup
    for i in {1..120}; do echo "data $i" > "$TEST_DIR/file$i.txt"; done
    $SCRIPT delete "$TEST_DIR"/* &>/dev/null
    assert_success "Delete 120 files"
}

test_list_large_bin() {
    echo "=== Test: List Recycle Bin with 100+ Items ==="
    setup
    for i in {1..150}; do echo "data $i" > "$TEST_DIR/file$i.txt"; done
    $SCRIPT delete "$TEST_DIR"/* &>/dev/null
    $SCRIPT list | grep -q "file1.txt"
    assert_success "List bin with 150 items"
}

# ============================
# Run Tests
# ============================
echo "========================================="
echo " Recycle Bin Comprehensive Test Suite"
echo "========================================="
setup
test_initialization
test_delete_single_file
test_delete_multiple_files
test_delete_empty_dir
test_delete_dir_with_contents
test_list_empty
test_list_with_items
test_restore_file
test_restore_nonexistent_path
test_empty_recyclebin
test_search_existing_file
test_search_nonexistent_file
test_display_help
test_delete_nonexistent_file
test_delete_no_permissions
test_restore_existing_filename
test_restore_invalid_id
test_handle_spaces_special_chars
test_long_filename
test_large_file
test_symlink
test_hidden_file
test_invalid_args
test_missing_params
test_corrupted_metadata
test_insufficient_space
test_permission_denied
test_delete_many_files
test_list_large_bin
teardown
echo "========================================="
echo "Results: $PASS passed, $FAIL failed"
echo "========================================="
[ $FAIL -eq 0 ] && exit 0 || exit 1
