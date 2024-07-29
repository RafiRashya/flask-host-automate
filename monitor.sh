#!/bin/bash

CREDENTIALS_FILE="credentials.txt"
SETUP_SCRIPT="config.sh"

inotifywait -m -e close_write --format '%w%f' "$CREDENTIALS_FILE" | while read FILE
do
    echo "Detected changes in $FILE. Running setup script..."
    bash "$SETUP_SCRIPT"
done