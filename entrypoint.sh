#!/bin/bash

set -e

if [ -z "$TALOS_VERSION" ]; then
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
