#!/bin/bash
set -e

# ====== CONFIG PATHS ======
UPLOAD_DIR="/opt/fatack/upload_temp_prod"
BACKUP_DIR="/opt/fatack/backup_$(date +%Y%m%d_%H%M%S)"
TARGET_DIR="/opt/fatack/ofsaa"

mkdir -p "$BACKUP_DIR"

# ====== ROLLBACK FUNCTION ======
rollback_now() {
    echo "⚠ Validation failed! Rolling back..."

    if [ -d "$BACKUP_DIR" ]; then
        echo "Hell ofrom inner directory "
        cp -r "$BACKUP_DIR"/* "$TARGET_DIR"/ 2>/dev/null || true
    fi

    echo "✔ Rollback completed"
    exit 1
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
            echo "Checking XML: $(basename "$file")"
            xmllint --noout "$file" || {
                echo "❌ Invalid XML format!"
                rollback_now
            }
            ;;

        *.sql)
            echo "Checking SQL: $(basename "$file")"
            python3 -c "
import sqlparse
with open(r'$file', 'r') as f:
    sqlparse.parse(f.read())
" || {
                echo "❌ Invalid SQL format!"
                rollback_now
            }
            ;;

        *.txt)
            echo "Checking TXT: $(basename "$file")"
            if ! file "$file" | grep -qi "text"; then
                echo "❌ Invalid TXT file!"
                rollback_now
            fi
            ;;
    esac

    echo "✔ Valid file: $(basename "$file")"
}

validate_folder() {
    local folder="$1"

    [ ! -d "$folder" ] && return 0

    echo "Validating folder: $folder"

    shopt -s nullglob
    local files=("$folder"/*)

    for file in "${files[@]}"; do
        if [ -d "$file" ]; then
            validate_folder "$file"
        else
            case "$file" in
                *.xml|*.sql|*.txt)
                    validate_file "$file"
                    ;;
                *)
                    echo "✔ Allowed file: $(basename "$file")"
                    ;;
            esac
        fi
    done
}

# ====== RUN VALIDATION ======
for dir in "$UPLOAD_DIR"/*; do
    if [ -d "$dir" ]; then
        validate_folder "$dir"
    fi
done

# echo "✔ All validations completed successfully"

# ====== MOVE UPLOAD_DIR TO TARGET_DIR ======
if [ -d "$UPLOAD_DIR" ]; then
    echo "Moving validated files from $UPLOAD_DIR to $TARGET_DIR..."
    cp -r "$UPLOAD_DIR"/* "$TARGET_DIR"/ || {
        echo "❌ Failed to move files. Triggering rollback."
        rollback_now
    }
    echo "✔ Deployment completed successfully"
else
    echo "❌ Upload directory $UPLOAD_DIR does not exist. Triggering rollback."
    rollback_now
fi

