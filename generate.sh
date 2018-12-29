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

required_commands()
{
    for cmd in "$@"; do
        if ! type "$cmd" >/dev/null 2>&1; then
            echo "$0: dependency $cmd not found"
            return 1
        fi
    done
}

required_directories()
{
    for dir in "$@"; do
        if [ ! -d "$dir" ]; then
            echo "$0: directory $dir does not exist" >&2
            return 1
        fi
    done
}

mklive()
{
    sudo "$MKLIVE_BIN" "$@"
}

cleanup()
{
    [[ -d "$BUILD_DIRECTORY" ]] && sudo rm -rf "$BUILD_DIRECTORY"
}

# house keeping
trap cleanup EXIT

# declarations
readonly PROJECT_DIRECTORY="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
readonly MKLIVE_DIRECTORY="${PROJECT_DIRECTORY}/mklive"
readonly MKLIVE_BIN="${MKLIVE_DIRECTORY}/mklive.sh"
readonly TEST_BIN="${PROJECT_DIRECTORY}/test.sh"

readonly IMAGE_NAME='installer-void'
readonly ARCH='x86_64'
readonly KEYMAP='us'
readonly LOCALE='en_CA.UTF-8'
readonly INITRAMFS_COMPRESSION='no-compress'

readonly XBPS_CACHEDIR="/tmp/installer-void-${ARCH}"
readonly BUILD_DIRECTORY="$(mktemp -d)"

readonly DATE="$(date +%Y-%m-%d)"
readonly OUTPUT_FILE="${IMAGE_NAME}-${ARCH}-${DATE}.iso"

# TODO: If I want a live cd: live.autologin=true live.user=william live.shell=/bin/bash
readonly BOOT_CMDLINE="auto autourl=file:///run/initramfs/live/boot/data/autoinstall.cfg"

readonly GRUB_PACKAGES="grub-i386-efi grub-x86_64-efi"
readonly BASE_PACKAGES="dialog cryptsetup lvm2 mdadm $GRUB_PACKAGES"
readonly X11_PACKAGES="$BASE_PACKAGES xorg-minimal xorg-input-drivers xorg-video-drivers setxkbmap xauth font-misc-misc terminus-font dejavu-fonts-ttf alsa-plugins-pulseaudio intel-ucode"
readonly PACKAGES="$X11_PACKAGES " # TODO: any additional packages

# TODO: make params for these?
readonly CONFIG_DIR="/config"
readonly CONFIG_PRIVATE_DIR="/config-private"
readonly AUTOINSTALL_FILE="${PROJECT_DIRECTORY}/autoinstall.cfg"

# check
required_commands "$MKLIVE_BIN"
required_directories "$CONFIG_DIR" "$CONFIG_PRIVATE_DIR"

# build up directory with things to include
sudo mkdir "$BUILD_DIRECTORY/data"
sudo rsync -ra --delete "$CONFIG_DIR/" "$BUILD_DIRECTORY/data/config"
sudo rsync -ra --delete "$CONFIG_PRIVATE_DIR/" "$BUILD_DIRECTORY/data/config-private"
sudo cp -f "$AUTOINSTALL_FILE" "$BUILD_DIRECTORY/data/autoinstall.cfg"

# prepare mklive
quiet pushd "$MKLIVE_DIRECTORY"
quiet make

# build image
export XBPS_HOST_CACHEDIR="$XBPS_CACHEDIR"
mklive \
    -a "$ARCH" \
    -k "$KEYMAP" \
    -l "$LOCALE" \
    -i "$INITRAMFS_COMPRESSION" \
    -I "INCLUDE_DIRECTORY" \
    -p "$PACKAGES" \
    -I "$BUILD_DIRECTORY" \
    -c "$XBPS_CACHEDIR" \
    -o "$OUTPUT_FILE" \
    -C "$BOOT_CMDLINE" \
    -T "$IMAGE_NAME"

# TODO: parameterize
"$TEST_BIN" "$IMAGE_NAME" "${MKLIVE_DIRECTORY}/${OUTPUT_FILE}"
