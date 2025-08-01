#!/usr/bin/env bash

set -Eeuo pipefail

if [ -z "${TALOS_VERSION:-}" ]; then
    echo "Error: TALOS_VERSION environment variable not set."
    exit 1
fi

echo "Fetching ZFS image for Talos version: $TALOS_VERSION..."
if ! ZFS_IMAGE=$(crane export "ghcr.io/siderolabs/extensions:${TALOS_VERSION}" | tar x -O image-digests | grep zfs | awk '{print $1}'); then
    echo "Error: Could not find a compatible ZFS extension for Talos $TALOS_VERSION."
    exit 1
fi

echo "Verifying ZFS image signature..."
if ! cosign verify \
    --certificate-identity-regexp '@siderolabs\.com$' \
    --certificate-oidc-issuer https://accounts.google.com \
    "$ZFS_IMAGE" >/dev/null 2>&1; then
    echo "Error: Image signature verification failed for $ZFS_IMAGE."
    exit 1
fi

echo "Installing ZFS from $ZFS_IMAGE..."
if ! crane export "$ZFS_IMAGE" | tar --strip-components=1 -x -C /; then
    echo "Error: Failed to extract ZFS extension."
    exit 1
fi

echo "ZFS tools installed successfully!"

if [ -z "${DEVICES:-}" ]; then
    echo "Error: DEVICES environment variable not set."
    echo "Example: export DEVICES=\"/dev/sda /dev/sdb /dev/sdc /dev/sdd\""
    exit 1
fi

if [ -z "${ASHIFT:-}" ]; then
    echo "Error: ASHIFT environment variable not set."
    echo "Example: export ASHIFT=12"
    exit 1
fi

: "${POOL_NAME:=zfspool}"

read -ra devices <<< "$DEVICES"

for device in "${devices[@]}"; do
    if [ ! -e "$device" ]; then
        echo "Error: Device $device does not exist."
        exit 1
    fi
done

create_zpool_mirror() {
    local ashift="$ASHIFT"
    local pool_name="$POOL_NAME"
    local -a zpool_cmd=("zpool" "create" "-m" "legacy" "-o" "ashift=$ashift" "-f" "$pool_name")

    if [ $(( ${#devices[@]} % 2 )) -ne 0 ]; then
        echo "Error: The number of devices must be even (each mirror requires 2 devices)."
        exit 1
    fi

    for (( i=0; i<${#devices[@]}; i+=2 )); do
        zpool_cmd+=("mirror" "${devices[i]}" "${devices[i+1]}")
    done

    echo "Creating ZFS pool with the following command:"
    echo "${zpool_cmd[@]}"

    if ! "${zpool_cmd[@]}"; then
        echo "Error: Failed to create ZFS pool."
        exit 1
    fi

    echo "ZFS pool '$pool_name' created successfully!"
    zpool status
}

create_zpool_mirror
