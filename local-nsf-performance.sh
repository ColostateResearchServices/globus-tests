#!/bin/bash

# Default values
BLOCK_SIZE="1M"
COUNT="51200" # 1M * 1024 = 1GB ; 51200 = 50GB ; 512000 = 500GB
LOCAL_DIR="/local/path"
NFS_DIR="/nfs/path"
OUTPUT_FILE="performance_test_results.txt"

# Help message function
print_help() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -h, --help                Show this help message and exit."
    echo "  -b, --block-size SIZE     Set the block size for the test file (e.g., 512K, 1M). Default is 1M."
    echo "  -c, --count COUNT         Set the count of blocks for the test file. Default is 51200."
    echo "  -l, --local-dir DIRECTORY Path to the local directory for testing. Default is /local/path."
    echo "  -n, --nfs-dir DIRECTORY   Path to the NFS mounted directory for testing. Default is /nfs/path."
    echo
    echo "Examples:"
    echo "  $0 --help"
    echo "      Display the help message."
    echo
    echo "  $0 -b 512K -c 2048 -l /mnt/local -n /mnt/nfs"
    echo "      Run tests with a file size of 1GB (512K blocks * 2048), using /mnt/local as the local directory"
    echo "      and /mnt/nfs as the NFS directory."
    echo
    echo "  $0 --block-size 1M --count 512 --local-dir /data/local --nfs-dir /data/nfs"
    echo "      Run tests with a 512MB file size (1M blocks * 512), using /data/local as the local directory"
    echo "      and /data/nfs as the NFS directory."
    exit 0
}

# Parse command line options
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help) print_help ;;
        -b|--block-size) BLOCK_SIZE="$2"; shift ;;
        -c|--count) COUNT="$2"; shift ;;
        -l|--local-dir) LOCAL_DIR="$2"; shift ;;
        -n|--nfs-dir) NFS_DIR="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Function to test write performance using dd
test_write_performance() {
    local dir=$1
    local file_name="testfile_$RANDOM"
    echo "Testing write performance on $dir"
    { time dd if=/dev/zero of=$dir/$file_name bs=$BLOCK_SIZE count=$COUNT oflag=direct conv=fsync; } 2>&1 | tee -a $OUTPUT_FILE
    echo "Write test completed for $dir" | tee -a $OUTPUT_FILE
    # Cleanup
    rm -f $dir/$file_name
}

# Function to test read performance using dd
test_read_performance() {
    local dir=$1
    local file_name="testfile_$RANDOM"
    # Creating a file for read test
    dd if=/dev/zero of=$dir/$file_name bs=$BLOCK_SIZE count=$COUNT oflag=direct conv=fsync &>/dev/null
    echo "Testing read performance on $dir"
    { time dd if=$dir/$file_name of=/dev/null bs=$BLOCK_SIZE; } 2>&1 | tee -a $OUTPUT_FILE
    echo "Read test completed for $dir" | tee -a $OUTPUT_FILE
    # Cleanup
    rm -f $dir/$file_name
}

# Function to test copy performance using cp
test_copy_performance() {
    local source_dir=$1
    local dest_dir=$2
    local file_name="testfile_$RANDOM"
    # Creating a file for copy test
    dd if=/dev/zero of=$source_dir/$file_name bs=$BLOCK_SIZE count=$COUNT oflag=direct conv=fsync &>/dev/null
    echo "Testing copy performance from $source_dir to $dest_dir"
    { time cp $source_dir/$file_name $dest_dir/; sync; } 2>&1 | tee -a $OUTPUT_FILE
    echo "Copy test completed from $source_dir to $dest_dir" | tee -a $OUTPUT_FILE
    # Cleanup
    rm -f $source_dir/$file_name
    rm -f $dest_dir/$file_name
}

# Main
echo "Starting performance tests with block size $BLOCK_SIZE, count $COUNT, local directory $LOCAL_DIR, and NFS directory $NFS_DIR" | tee $OUTPUT_FILE
test_write_performance $LOCAL_DIR
test_read_performance $LOCAL_DIR
test_copy_performance $LOCAL_DIR $NFS_DIR
test_write_performance $NFS_DIR
test_read_performance $NFS_DIR
test_copy_performance $NFS_DIR $LOCAL_DIR
echo "Performance tests completed." | tee -a $OUTPUT_FILE