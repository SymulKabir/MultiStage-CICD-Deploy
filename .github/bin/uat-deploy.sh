#!/bin/bash
set -e

echo "====== UAT Deployment Script Started ======"

timestamp=$(date +%Y%m%d_%H%M%S)

UPLOAD_DIR="/opt/fatack/upload_temp_uat"
TARGET_DIR="/opt/fatack/ofsaa"
BACKUP_DIR="/opt/fatack/backup_uat_$timestamp"

# -----------------------
# Rollback function
# -----------------------
rollback() {
    echo "❌ Deployment FAILED. Rolling back..."
    if [ -d "$BACKUP_DIR" ]; then
        rm -rf "$TARGET_DIR"
        mkdir -p "$TARGET_DIR"
        cp -r "$BACKUP_DIR"/* "$TARGET_DIR"/
        echo "✔ Rollback completed. System restored."
    else
        echo "⚠ No backup found! Rollback FAILED."
    fi
}

trap rollback ERR

echo "Creating backup of existing UAT files..."
mkdir -p "$BACKUP_DIR"

if [ -d "$TARGET_DIR" ] && [ "$(ls -A "$TARGET_DIR")" ]; then
  cp -r "$TARGET_DIR"/* "$BACKUP_DIR"/
  echo "Backup completed at $BACKUP_DIR"
else
  echo "Target is empty. Skipping backup."
fi

# -----------------------
# Safe move function
# -----------------------
move_folder() {
    local src="$1"
    local dest="$2"

    if [ -d "$UPLOAD_DIR/$src" ]; then
        echo "Deploying $src..."
        mkdir -p "$dest"

        mv "$UPLOAD_DIR/$src"/* "$dest"/ || {
            echo "❌ ERROR: Failed to move $src"
            return 1
        }

        echo "$src deployed to $dest"
    else
        echo "Folder $src does not exist. Skipping..."
    fi
}

# Deploy folders
move_folder "bdf-datamaps" "$TARGET_DIR/bdf/config/datamaps"
move_folder "custom-datamaps" "$TARGET_DIR/bdf/config/customs"
move_folder "ingestion-manager" "$TARGET_DIR/ingestion_manager/config"
move_folder "scenarios" "$TARGET_DIR/bdf/config"
move_folder "controlm-scripts" "$TARGET_DIR/ESP/scripts"

echo "Cleaning upload directory..."
rm -rf "$UPLOAD_DIR"

echo "====== UAT Deployment Completed Successfully ======"
