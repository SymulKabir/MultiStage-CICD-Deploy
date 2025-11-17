#!/bin/bash

UPLOAD_DIR="/opt/fatack/upload_temp"

TARGET_BDF="/opt/fatack/ofsaa/bdf/config/datamaps"
TARGET_CUSTOM="/opt/fatack/ofsaa/bdf/config/customs"
TARGET_INGEST="/opt/fatack/ofsaa/ingestion_manager/config"
TARGET_SCENARIOS="/opt/fatack/ofsaa/bdf/config"
TARGET_CTM="/opt/fatack/ofsaa/ESP/scripts"

LOG_FILE="/var/log/dev_deploy.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

############################################
# FILE VALIDATION (.txt / .sql / .xml)
############################################
validate_files() {
    DIR="$1"
    log "Starting file validation inside: $DIR"

    # Validate .txt
    find "$DIR" -type f -name "*.txt" 2>/dev/null | while read file; do
        if [ ! -s "$file" ]; then
            log "ERROR: Empty .txt file: $file"
            exit 1
        fi
        
        if ! iconv -f utf-8 -t utf-8 "$file" >/dev/null 2>&1; then
            log "ERROR: Invalid UTF-8 .txt file: $file"
            exit 1
        fi
    done

    # Validate .sql
    find "$DIR" -type f -name "*.sql" 2>/dev/null | while read file; do
        if [ ! -s "$file" ]; then
            log "ERROR: Empty .sql file: $file"
            exit 1
        fi
        
        QUOTES=$(grep -o "'" "$file" | wc -l)
        if [ $((QUOTES % 2)) -ne 0 ]; then
            log "ERROR: Unclosed SQL quote in: $file"
            exit 1
        fi
    done

    # Validate .xml
    find "$DIR" -type f -name "*.xml" 2>/dev/null | while read file; do
        if [ ! -s "$file" ]; then
            log "ERROR: Empty .xml file: $file"
            exit 1
        fi

        if ! xmllint --noout "$file" 2>/dev/null; then
            log "ERROR: Invalid XML structure in: $file"
            exit 1
        fi
    done

    log "File validation passed successfully."
}

############################################
# MOVE FUNCTION
############################################
move_folder() {
    FOLDER_NAME=$1
    SRC="$UPLOAD_DIR/$FOLDER_NAME"
    DEST="$2"

    log "Processing: $FOLDER_NAME"

    if [ ! -d "$SRC" ] || [ -z "$(ls -A "$SRC")" ]; then
        log "SKIPPED: $FOLDER_NAME does not exist or is empty"
        return
    fi

    if [ ! -d "$DEST" ]; then
        log "Destination missing → Creating: $DEST"
        mkdir -p "$DEST" || { log "ERROR: Cannot create $DEST"; exit 1; }
    fi

    log "Moving $FOLDER_NAME → $DEST"
    mv "$SRC"/* "$DEST"/ 2>>"$LOG_FILE" || {
        log "ERROR: Failed moving files from $SRC to $DEST"
        exit 1
    }

    log "$FOLDER_NAME deployment completed."
}

############################################
# RUN DEPLOYMENT
############################################
log "==== STARTING DEV DEPLOYMENT ===="

validate_files "$UPLOAD_DIR"

move_folder "bdf-datamaps" "$TARGET_BDF"
move_folder "custom-datamaps" "$TARGET_CUSTOM"
move_folder "ingestion-manager" "$TARGET_INGEST"
move_folder "scenarios" "$TARGET_SCENARIOS"
move_folder "controlm-scripts" "$TARGET_CTM"

log "==== DEV DEPLOYMENT FINISHED SUCCESSFULLY ===="
