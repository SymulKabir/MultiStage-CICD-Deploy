#!/bin/bash
set -e

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
        echo "✔ $tool is already installed"
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
            echo "Checking XML with xmllint: $(basename "$file")"
            xmllint --noout "$file" || {
                echo "❌ Invalid XML format!"
                return 1
            }
            ;;

        *.sql)
            echo "Checking SQL using sqlformat: $(basename "$file")"
            sqlformat "$file" >/dev/null 2>&1 || {
                echo "❌ Invalid SQL format!"
                return 1
            }
            ;;

        *.txt)
            echo "Checking TXT: $(basename "$file")"
            if ! file "$file" | grep -qi "text"; then
                echo "❌ Invalid TXT file (not readable text)"
                return 1
            fi
            ;;
    esac

    echo "✔ Valid file: $(basename "$file")"
}

validate_folder() {
    local folder="$1"
    local path="$UPLOAD_DIR/$folder"

    [ ! -d "$path" ] && return 0

    shopt -s nullglob
    local files=("$path"/*)

    for file in "${files[@]}"; do
        case "$file" in
            *.xml|*.sql|*.txt)
                validate_file "$file" || return 1
                ;;
            *)
                echo "✔ Allowed file: $(basename "$file") (no validation needed)"
                ;;
        esac
    done
}
