#!/bin/bash
set -e

# ====== CONFIG PATHS ======
UPLOAD_DIR="/opt/fatack_uti/upload_temp"
TARGET_DIR="/opt/fatack/ofsaa"
BACKUP_BASE="/opt/fatack_uti/backups"
VERSION=$(date +%Y%m%d_%H%M%S)
ROLLBACK=$1
ROLLBACK_VERSION=$2

mkdir -p "$BACKUP_BASE"

# ====== ROLLBACK FUNCTION ======
rollback_now() {
    local version="$1"
    
    if [ -z "$version" ]; then
        echo "⚠ No rollback version specified, using latest backup..."
        version=$(ls -1 "$BACKUP_BASE" | sort -r | head -n1)
    fi

    if [ -z "$version" ] || [ ! -d "$BACKUP_BASE/$version" ]; then
        echo "❌ No backup available to rollback!"
        exit 1
    fi

    echo "🔄 Rolling back to version: $version"
    sudo rm -rf "$TARGET_DIR"/*
    sudo cp -r "$BACKUP_BASE/$version"/* "$TARGET_DIR"/
    echo "✔ Rollback completed successfully to version: $version"
    exit 0
}

# ====== CHECK & INSTALL REQUIRED TOOLS ======
install_if_missing() {
    local tool="$1"
    local package="$2"
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "⚠ $tool not found. Installing $package..."
        sudo apt update -y
        sudo apt install -y "$package"
        echo "✔ Installed: $tool"
    else
        echo "✔ $tool already installed"
    fi
}

install_if_missing "xmllint" "libxml2-utils"
install_if_missing "python3" "python3"
install_if_missing "sqlformat" "python3-sqlparse"
install_if_missing "file" "file"

echo "====== All validation tools are ready ======"

# ====== VALIDATION FUNCTIONS ======
validate_file() {
    local file="$1"
    case "$file" in
        *.xml)
            xmllint --noout "$file" || { echo "❌ Invalid XML: $file"; rollback_now "$ROLLBACK_VERSION"; }
            ;;
        *.sql)
            python3 -c "
import sqlparse
with open(r'$file', 'r') as f:
    sqlparse.parse(f.read())
" || { echo "❌ Invalid SQL: $file"; rollback_now "$ROLLBACK_VERSION"; }
            ;;
        *.txt)
            if ! file "$file" | grep -qi "text"; then
                echo "❌ Invalid TXT file: $file"
                rollback_now "$ROLLBACK_VERSION"
            fi
            ;;
        *)
            echo "✔ Allowed file: $(basename "$file")"
            ;;
    esac
    echo "✔ Valid file: $(basename "$file")"
}

validate_folder() {
    local folder="$1"
    [ ! -d "$folder" ] && return 0
    shopt -s nullglob
    for file in "$folder"/*; do
        if [ -d "$file" ]; then
            validate_folder "$file"
        else
            validate_file "$file"
        fi
    done
}

# ====== HANDLE MANUAL ROLLBACK ======
if [ "$ROLLBACK" == "true" ]; then
    rollback_now "$ROLLBACK_VERSION"
fi

# ====== VALIDATE UPLOAD ======
for dir in "$UPLOAD_DIR"/*; do
    [ -d "$dir" ] && validate_folder "$dir"
done

# ====== BACKUP CURRENT DEPLOYMENT ======
if [ -d "$TARGET_DIR" ]; then
    BACKUP_DIR="$BACKUP_BASE/$VERSION"
    echo "Backing up current deployment to: $BACKUP_DIR"
    sudo cp -r "$TARGET_DIR" "$BACKUP_DIR"
fi

# ====== DEPLOY NEW FILES ======
echo "Deploying new files from $UPLOAD_DIR to $TARGET_DIR"
sudo mkdir -p "$TARGET_DIR"
sudo cp -r "$UPLOAD_DIR"/* "$TARGET_DIR"/ || { echo "❌ Deployment failed! Triggering rollback."; rollback_now "$ROLLBACK_VERSION"; }

echo "✔ Deployment completed successfully (version: $VERSION)"
