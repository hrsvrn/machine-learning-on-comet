#!/bin/bash

# Script to consolidate all Linux command JSON files into a single linux-commands.json file
# Author: hrsvrn [Harshvardhan Vatsa]
# Usage: ./consolidate_linux_commands.sh

set -e  # Exit on any error

# Define paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINUX_COMMANDS_DIR="Datasets/Linux-Commands-for-the-mecha"
OUTPUT_FILE="$LINUX_COMMANDS_DIR/linuxcommands.json"
TEMP_DIR="/tmp/consolidation_$$"

echo "Linux Commands Consolidation Script"
echo "Source directory: $LINUX_COMMANDS_DIR"
echo "Output file: $OUTPUT_FILE"
echo ""

# Check if source directory exists
if [[ ! -d "$LINUX_COMMANDS_DIR" ]]; then
    echo "Error: Linux-Commands-for-the-mecha directory not found at $LINUX_COMMANDS_DIR"
    exit 1
fi

# Check if jq is available for JSON processing
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required for JSON processing but not found."
    echo "Please install jq: sudo apt-get install jq"
    exit 1
fi

# Create temporary directory
mkdir -p "$TEMP_DIR"

# Counter for tracking progress
file_count=0
entry_count=0
error_count=0

echo "Processing JSON files..."

# Collect all valid JSON files into a list
valid_files=()
while IFS= read -r -d '' json_file; do
    # Skip the consolidated file itself and any backup files
    if  [[ "$(basename "$json_file")" == "linuxcommands.json" ]]; then
        echo "Skipping existing consolidated file: $json_file"
        continue
    fi
    
    echo "Processing: $json_file"
    
    # Check if file is empty
    if [[ ! -s "$json_file" ]]; then
        echo "  → Skipping empty file"
        continue
    fi
    
    # Validate JSON
    if jq empty "$json_file" 2>/dev/null; then
        # Check if it's a non-empty array
        if entry_count_file=$(jq 'length' "$json_file" 2>/dev/null) && [[ $entry_count_file -gt 0 ]]; then
            valid_files+=("$json_file")
            file_count=$((file_count + 1))
            entry_count=$((entry_count + entry_count_file))
            echo "  → Valid JSON with $entry_count_file entries"
        else
            echo "  → Empty JSON array, skipping"
        fi
    else
        echo "  → Invalid JSON format, skipping"
        error_count=$((error_count + 1))
    fi
    
done < <(find "$LINUX_COMMANDS_DIR" -name "*.json" -type f -print0)

echo ""
echo "Found $file_count valid JSON files with $entry_count total entries"

if [[ ${#valid_files[@]} -eq 0 ]]; then
    echo "Error: No valid JSON files found to consolidate"
    exit 1
fi

echo "Consolidating JSON files..."

# Use jq to properly merge all JSON arrays
if [[ ${#valid_files[@]} -eq 1 ]]; then
    # Only one file, just copy it
    jq '.' "${valid_files[0]}" > "$OUTPUT_FILE"
else
    # Multiple files, merge them using jq's add function
    # Build the jq command with all files
    jq_cmd="jq -s 'add'"
    for file in "${valid_files[@]}"; do
        jq_cmd="$jq_cmd $(printf '%q' "$file")"
    done
    eval "$jq_cmd" > "$OUTPUT_FILE"
fi

# Validate the final output
echo "Validating consolidated file..."
if jq empty "$OUTPUT_FILE" 2>/dev/null; then
    final_count=$(jq 'length' "$OUTPUT_FILE")
    echo "JSON validation successful!"
    echo "Final entry count: $final_count"
else
    echo "Error: Final JSON file is invalid"
    exit 1
fi

# Clean up
rm -rf "$TEMP_DIR"

echo ""
echo "Consolidation Complete"
echo "Files processed: $file_count"
echo "Files with errors: $error_count"
echo "Total entries: $final_count"
echo "Output saved to: $OUTPUT_FILE"
echo ""

# Show file size
if command -v du &> /dev/null; then
    file_size=$(du -h "$OUTPUT_FILE" | cut -f1)
    echo "Output file size: $file_size"
fi

echo "Done!" 