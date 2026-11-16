#!/usr/bin/env bash
# Recover deleted photos from a microSD card using photorec (testdisk).
# Usage:
#   ./recover-sd.sh [destination_folder]              -> with a dd image (safer, takes as much space as the SD card)
#   ./recover-sd.sh --no-image [destination_folder]   -> directly from the SD card (no image, takes no extra space)
# Default destination: ~/recovered_photos

set -euo pipefail

NO_IMAGE=0
if [[ "${1:-}" == "--no-image" ]]; then
    NO_IMAGE=1
    shift
fi

DEST="${1:-$HOME/recovered_photos}"

# 1. Dependencies
if ! command -v photorec >/dev/null 2>&1; then
    echo "photorec is not installed. Installing with brew..."
    brew install testdisk
fi

mkdir -p "$DEST"

# 2. Identify the SD card
echo
echo "=== External disks detected ==="
diskutil list external
echo
echo "Insert the SD card if you haven't yet and press Enter to refresh, or type the identifier."
read -rp "SD card identifier (e.g. disk4, without /dev/): " DISK

if [[ -z "$DISK" ]]; then
    echo "Refreshing:"
    diskutil list external
    read -rp "SD card identifier: " DISK
fi

DEV="/dev/$DISK"
RDEV="/dev/r$DISK"

if [[ ! -e "$DEV" ]]; then
    echo "ERROR: $DEV does not exist"
    exit 1
fi

# 3. Confirmation
echo
echo "You are about to read $DEV. Check that it is the right SD card:"
diskutil info "$DEV" | grep -E "Device / Media Name|Disk Size|Protocol|Removable Media|Volume Name" || true
echo
read -rp "Confirm by typing YES: " CONF
[[ "$CONF" == "YES" ]] || { echo "Cancelled."; exit 1; }

# 4. Unmount so photorec can read the raw device
echo "Unmounting $DISK..."
diskutil unmountDisk "$DEV"

# 5. dd image (optional)
if [[ "$NO_IMAGE" -eq 1 ]]; then
    TARGET="$RDEV"
    echo
    echo "--no-image mode: photorec will read $RDEV directly (read-only, nothing is written to the SD card)."
else
    IMG="$DEST/sd_image.dd"
    if [[ -f "$IMG" ]]; then
        read -rp "$IMG already exists. Reuse it (r) or overwrite it (o)? [r/o]: " OPT
        if [[ "$OPT" == "o" ]]; then
            rm -f "$IMG"
        fi
    fi

    if [[ ! -f "$IMG" ]]; then
        echo "Creating image at $IMG (this can take a while depending on the size of the SD card)..."
        sudo dd if="$RDEV" of="$IMG" bs=4194304 status=progress
        sudo chown "$(whoami)" "$IMG"
    fi
    TARGET="$IMG"
fi

# 6. Launch photorec
echo
echo "=== Launching photorec ==="
echo "In the TUI:"
echo "  1) Partition -> usually the only one listed, or [Whole disk]"
echo "  2) Filesystem type -> [Other] (FAT/NTFS/exFAT)"
echo "  3) Free / Whole -> [Whole] to scan all the space"
echo "  4) Destination folder -> navigate to $DEST and press C"
echo
echo "To recover only photos: in the File Opt menu before starting,"
echo "press 's' to deselect everything, then enable jpg, tif, png, raw, etc."
echo
read -rp "Press Enter to continue..." _

if [[ "$NO_IMAGE" -eq 1 ]]; then
    sudo photorec "$TARGET"
else
    photorec "$TARGET"
fi

echo
echo "=== Done ==="
echo "Recovered photos are in recup_dir.* subfolders inside $DEST"
if [[ "$NO_IMAGE" -eq 0 ]]; then
    echo "Original image: $IMG (you can delete it once you have what you wanted)"
fi
