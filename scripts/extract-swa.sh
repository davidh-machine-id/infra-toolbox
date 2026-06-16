#!/bin/bash

# ============================================================
# Extract SWA Release Tarball
# ============================================================
# Finds the latest swa-release-v*.tgz in dist/ (by semver)
# and extracts it directly to swa-release/ (no subdirectory wrapper)
# ============================================================

set -aeuo pipefail

SETUP_ENV_FILE="${PROJECT_ROOT}/setup.env"
if ! [[ -f "${SETUP_ENV_FILE}" ]]; then
	echo "ERROR: setup.env file does not exist, stopping."
	echo "       expected ${SETUP_ENV_FILE} to exist."
	exit 1
fi
source "${SETUP_ENV_FILE}"

REL_PROJECT_ROOT="${PROJECT_ROOT#$HOME/}"

echo ""
echo "⚠️  WARNING: The swa-release/ directory contains contents"
echo "    from the tarball. Do not manually edit these files."
echo ""

# Check if dist directory exists
if [ ! -d "${PROJECT_ROOT}/dist" ]; then
	echo "ERROR: ${PROJECT_ROOT}/dist/ directory not found"
	exit 1
fi

# Find the latest version swa-release*-v*.tgz file (sorted by semver)
TARBALL=$(find ${PROJECT_ROOT}/dist -maxdepth 1 -name "swa-release*-v*.tgz" -type f | sort -V | tail -1)

if [ -z "$TARBALL" ]; then
	echo "ERROR: No swa-release*-v*.tgz file found in ${REL_PROJECT_ROOT}/dist/"
	exit 1
fi

echo "Found: $(basename "$TARBALL")"

# Remove existing swa-release directory
if [ -d "${PROJECT_ROOT}/swa-release" ]; then
	rm -rf ${PROJECT_ROOT}/swa-release
fi

# Create fresh swa-release directory
mkdir -p ${PROJECT_ROOT}/swa-release

# Extract tarball, stripping top-level directory
if ! tar -xzf "$TARBALL" -C ${PROJECT_ROOT}/swa-release --strip-components=1; then
	echo "✗ Failed to extract tarball"
	exit 1
fi

echo "Extracted to: ${REL_PROJECT_ROOT}/swa-release/"
