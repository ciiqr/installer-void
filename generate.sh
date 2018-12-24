#!/usr/bin/env bash

# exit on command failure
set -e

# functions
quiet()
{
    declare out="$(mktemp)"
    declare ret=0

    if ! "$@" </dev/null >"$out" 2>&1; then
        ret=1
        cat "$out" >&2
    fi

    rm -f "$out"
    return "$ret"
}

dependencies()
{
    # required commands
    for cmd in "$@"; do
        if ! type "$cmd" >/dev/null 2>&1; then
            echo "$0: dependency $cmd not found"
            return 1
        fi
    done
}

mklive()
{
    "$MKLIVE_BIN" "$@"
}

cleanup()
{
    [[ -d "$BUILD_DIRECTORY" ]] && rm -rf "$BUILD_DIRECTORY"
}

# house keeping
trap cleanup EXIT

# declarations
readonly PROJECT_DIRECTORY="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
readonly MKLIVE_DIRECTORY="${PROJECT_DIRECTORY}/mklive"
readonly MKLIVE_BIN="${MKLIVE_DIRECTORY}/mklive.sh" "$@"

readonly IMAGE_NAME="installer-void"
readonly ARCH='x86_64'
readonly KEYMAP='us'
readonly LOCALE='en_CA.UTF-8'

readonly XBPS_CACHEDIR="/tmp/installer-void-${ARCH}"
readonly BUILD_DIRECTORY="$(mktemp -d)"

readonly DATE="$(date +%Y-%m-%d)"
readonly OUTPUT_FILE="${IMAGE_NAME}-${ARCH}-${DATE}.iso"

readonly GRUB_PACKAGES="grub-i386-efi grub-x86_64-efi"
readonly BASE_PACKAGES="dialog cryptsetup lvm2 mdadm $GRUB_PACKAGES"
readonly X11_PACKAGES="$BASE_PACKAGES xorg-minimal xorg-input-drivers xorg-video-drivers setxkbmap xauth font-misc-misc terminus-font dejavu-fonts-ttf alsa-plugins-pulseaudio intel-ucode"
readonly PACKAGES="$X11_PACKAGES " # TODO: any additional packages

# check
dependencies "$MKLIVE_BIN"

# TODO: build up directory with things to include
# - config
# - config-private
# - basic script to run both above when provided
    # # move over config
    # data_path="/cdrom/data/config/."
    # if [ -d "$data_path" ]; then
    #     cp -rf "$data_path" "/target/config"
    # fi

    # # move over config-private
    # data_path="/cdrom/data/config-private/."
    # if [ -d "$data_path" ]; then
    #     cp -rf "$data_path" "/target/config-private"
    # fi

    # # install config
    # in-target bash /config/scripts/install --primaryUser "$primaryUser" --machine "$machine" --roles "$roles"

# prepare mklive
quiet pushd "$MKLIVE_DIRECTORY"
quiet make

# build image
export XBPS_HOST_CACHEDIR="$XBPS_CACHEDIR"
mklive \
    -a "$ARCH" \
    -k "$KEYMAP" \
    -l "$LOCALE" \
    -p "$PACKAGES" \
    -I "$BUILD_DIRECTORY" \
    -c "$XBPS_CACHEDIR" \
    -o "$OUTPUT_FILE" \
    -T "$IMAGE_NAME"

# TODO: might need
# C) BOOT_CMDLINE="$OPTARG";;

# TODO: test
# "${MKLIVE_DIRECTORY}/${OUTPUT_FILE}"
