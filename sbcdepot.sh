#!/bin/bash
set -euo pipefail

clear

# ─── CONFIG ──────────────────────────────────────────────────────────────────
# Replace YOUR_USERNAME and YOUR_REPO after creating the GitHub repo
DB_URL="https://raw.githubusercontent.com/kannanokannan/sbcdepot/main/apps.json"

# ─── HEADER ──────────────────────────────────────────────────────────────────
echo "========================================="
echo "        WELCOME TO THE SBC DEPOT          "
echo "   Community Driven · Zero Server Infra  "
echo "========================================="

# ─── DEPENDENCY CHECK ────────────────────────────────────────────────────────
if ! command -v jq &> /dev/null; then
    echo "Installing jq via apt..."
    sudo apt-get update -y && sudo apt-get install -y jq > /dev/null
fi

# ─── FETCH DATABASE ──────────────────────────────────────────────────────────
DB_FILE=$(mktemp /tmp/sbcdepot-db.XXXXXX)
trap 'rm -f "$DB_FILE"' EXIT

curl -sSf -H "User-Agent: SBCDepot-Client/1.0" "$DB_URL" > "$DB_FILE"

if [ ! -s "$DB_FILE" ]; then
    echo "Error: Could not fetch app database."
    exit 1
fi

# ─── DISPLAY APP LIST ────────────────────────────────────────────────────────
echo ""
echo "--- AVAILABLE APPS ---"
jq -r '.[] | "\(.id)) \(.name) — \(.description)"' "$DB_FILE"
echo "========================================="

# ─── USER INPUT ──────────────────────────────────────────────────────────────
read -r -p "Enter app number to install (or 'q' to quit): " CHOICE

if [[ "$CHOICE" == "q" ]]; then
    echo "Exiting SBC Depot."
    exit 0
fi

if [[ ! "$CHOICE" =~ ^[0-9]+$ ]]; then
    echo "Invalid input. Numbers only."
    exit 1
fi

# ─── EXTRACT FIELDS ──────────────────────────────────────────────────────────
RAW_APP_NAME=$(jq -r ".[] | select(.id == $CHOICE) | .name" "$DB_FILE")
METHOD=$(jq -r ".[] | select(.id == $CHOICE) | .method" "$DB_FILE")

if [ -z "$RAW_APP_NAME" ] || [ "$RAW_APP_NAME" == "null" ]; then
    echo "App not found."
    exit 1
fi

# Sanitize app name for safe terminal display
APP_NAME=$(echo "$RAW_APP_NAME" | tr -cd 'A-Za-z0-9 _-')

echo ""
echo "Processing: $APP_NAME via method: $METHOD"
echo "-----------------------------------------"

# ─── INSTALL LOGIC ───────────────────────────────────────────────────────────
case "$METHOD" in

    "apt")
        PKG_NAME=$(jq -r ".[] | select(.id == $CHOICE) | .package_name" "$DB_FILE")

        if [[ ! "$PKG_NAME" =~ ^[a-z0-9][a-z0-9+\-.]+$ ]]; then
            echo "Malicious package name detected. Aborting."
            exit 1
        fi

        sudo apt-get update && sudo apt-get install -y "$PKG_NAME"
        echo ""
        echo "$APP_NAME installed successfully."
        ;;

    "git_clone")
        REPO_URL=$(jq -r ".[] | select(.id == $CHOICE) | .repo_url" "$DB_FILE")
        DEST_DIR=$(jq -r ".[] | select(.id == $CHOICE) | .destination" "$DB_FILE")
        POST_NOTE=$(jq -r ".[] | select(.id == $CHOICE) | .post_install_note // empty" "$DB_FILE")

        # Validate repo URL
        if [[ ! "$REPO_URL" =~ ^https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
            echo "Invalid or unsafe repo URL. Aborting."
            exit 1
        fi

        # Block path traversal — no dots, no slashes
        if [[ ! "$DEST_DIR" =~ ^[A-Za-z0-9_-]+$ ]]; then
            echo "Malicious destination path detected. Aborting."
            exit 1
        fi

        git clone --depth=1 "$REPO_URL" "$HOME/$DEST_DIR"

        echo ""
        echo "Repository downloaded to ~/$DEST_DIR"

        # Post-install note — printf only, no echo -e, backslash stripped
        if [ -n "$POST_NOTE" ]; then
            CLEAN_NOTE=$(printf '%s' "$POST_NOTE" | tr -cd 'A-Za-z0-9 _./:~-')
            echo "-----------------------------------------"
            echo "Next step:"
            printf '  %s\n' "$CLEAN_NOTE"
        fi

        echo "========================================="
        ;;

    *)
        echo "Unknown install method: $METHOD. Aborting."
        exit 1
        ;;
esac
