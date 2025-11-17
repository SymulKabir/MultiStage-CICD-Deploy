#!/bin/bash
set -e

echo "====== Production Deployment Script Started ======"

timestamp=$(date +%Y%m%d_%H%M%S)

UPLOAD_DIR="/opt/fatack/upload_temp_prod"
TARGET_DIR="/opt/fatack/ofsaa"
BACKUP_DIR="/opt/fatack/backup_prod_$timestamp"

# -----------------------
# Rollback function
# -----------------------
rollback() {
    echo "❌ Deployment FAILED. Rolling back..."
    if [ -d "$BACKUP_DIR" ]; then
        rm -rf "$TARGET_DIR"
        mkdir -p "$TARGET_DIR"
        cp -r "$BACKUP_DIR"/* "$TARGET_DIR"/
        echo "✔ Rollback completed. System restored to previous production state."
    else
        echo "⚠ No backup found! Rollback FAILED."
    fi
}

trap rollback ERR

echo "Creating backup of existing Production files..."
mkdir -p "$BACKUP_DIR"

if [ -d "$TARGET_DIR" ] && [ "$(ls -A "$TARGET_DIR")" ]; then
  cp -r "$TARGET_DIR"/* "$BACKUP_DIR"/
  echo "Backup completed at $BACKUP_DIR"
else
  echo "Production target directory empty. Skipping backup."
fi

# -----------------------
# File validation function
# -----------------------
validate_files() {
    local folder="$1"
    local path="$UPLOAD_DIR/$folder"

    if [ ! -d "$path" ]; then
        echo "Skipping validation: $folder not found."
        return 0
    fi

    echo "Validating files in folder: $folder"

    shopt -s nullglob
    local files=("$path"/*)

    if [ ${#files[@]} -eq 0 ]; then
        echo "⚠ WARNING: $folder is empty — skipping deployment."
        return 0
    fi

    for f in "${files[@]}"; do
        case "$f" in
            *.txt|*.sql|*.xml)
                echo "✔ VALID: $(basename "$f")"
                ;;
            *)
                echo "❌ INVALID FILE TYPE: $(basename "$f")"
                echo "Allowed: .txt .sql .xml"
                return 1
                ;;
        esac
    done
}

# -----------------------
# Safe move function
# -----------------------
move_folder() {
    local src="$1"
    local dest="$2"

    validate_files "$src"

    if [ -d "$UPLOAD_DIR/$src" ]; then
        echo "Deploying $src..."
        mkdir -p "$dest"

        mv "$UPLOAD_DIR/$src"/* "$dest"/ || {
            echo "❌ ERROR: Failed moving $src"
            return 1
        }

        echo "$src deployed to $dest"
    else
        echo "Folder $src not found. Skipping..."
    fi
}

# -----------------------
# Deploy folders
# -----------------------
move_folder "bdf-datamaps" "$TARGET_DIR/bdf/config/datamaps"
move_folder "custom-datamaps" "$TARGET_DIR/bdf/config/customs"
move_folder "ingestion-manager" "$TARGET_DIR/ingestion_manager/config"
move_folder "scenarios" "$TARGET_DIR/bdf/config"
move_folder "controlm-scripts" "$TARGET_DIR/ESP/scripts"

echo "Cleaning temporary upload directory..."
rm -rf "$UPLOAD_DIR"

echo "====== Production Deployment Completed Successfully ======"
