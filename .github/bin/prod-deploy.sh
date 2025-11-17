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
            sqlformat "$file" >/dev/null 2>&1 || {
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
    local path="$UPLOAD_DIR/$folder"

    [ ! -d "$path" ] && return 0

    echo "Validating folder: $folder"

    shopt -s nullglob
    local files=("$path"/*)

    for file in "${files[@]}"; do
        case "$file" in
            *.xml|*.sql|*.txt)
                validate_file "$file"
                ;;
            *)
                echo "✔ Allowed file: $(basename "$file")"
                ;;
        esac
    done
}


# ====== RUN VALIDATION ====== 
for dir in "$UPLOAD_DIR"/*; do
    echo "Hello from $dir"
    validate_folder "$dir"
done

echo "✔ All validations completed successfully"
