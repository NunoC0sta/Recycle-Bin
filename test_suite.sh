#!/bin/bash
# Test Suite for Recycle Bin System
SCRIPT="./recycle_bin.sh"
TEST_DIR="test_data"
PASS=0
FAIL=0

#Auto Confirm for the Empty Recycle Bin Tests
export AUTO_CONFIRM="true"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
# Test Helper Functions
setup() {
    mkdir -p "$TEST_DIR"
    rm -rf ~/.recycle_bin
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

# Test Cases
test_initialization() {
    echo "=== Test: Initialization ==="
    setup
    $SCRIPT help > /dev/null
    assert_success "Initialize recycle bin"
    [ -d ~/.recycle_bin ] && echo "✓ Directory created"
    [ -f ~/.recycle_bin/metadata.db ] && echo "✓ Metadata file created"
}
test_delete_file() {
    echo "=== Test: Delete File ==="
    setup
    echo "test content" > "$TEST_DIR/test.txt"
    $SCRIPT delete "$TEST_DIR/test.txt"
    assert_success "Delete existing file"
    [ ! -f "$TEST_DIR/test.txt" ] && echo "✓ File removed from original location"
}
test_list_empty() {
    echo "=== Test: List Empty Bin ==="
    setup
    $SCRIPT list | grep -q "empty"
    assert_success "List empty recycle bin"
}
test_restore_file() {
    echo "=== Test: Restore File ==="
    setup
    echo "test" > "$TEST_DIR/restore_test.txt"
    $SCRIPT delete "$TEST_DIR/restore_test.txt"
    # Get file ID from list
    ID=$($SCRIPT list | grep "restore_test" | awk '{print $1}')
    $SCRIPT restore "$ID"
    assert_success "Restore file"
    [ -f "$TEST_DIR/restore_test.txt" ] && echo "✓ File restored"
}
# Run all tests
echo "========================================="
echo " Recycle Bin Test Suite"
echo "========================================="
test_initialization
test_delete_file
test_list_empty
test_restore_file
# Add more test functions here
teardown
echo "========================================="
echo "Results: $PASS passed, $FAIL failed"
echo "========================================="
[ $FAIL -eq 0 ] && exit 0 || exit 1