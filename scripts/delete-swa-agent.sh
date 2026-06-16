#!/usr/bin/env bash
set -aeuo pipefail

SETUP_ENV_FILE="${PROJECT_ROOT}/setup.env"
if ! [[ -f "${SETUP_ENV_FILE}" ]]; then
	echo "ERROR: setup.env file does not exist, stopping."
	echo "       expected ${SETUP_ENV_FILE} to exist."
	exit 1
fi
source "${SETUP_ENV_FILE}"

cd "$PROJECT_ROOT/swa-release/helm"

# Deploy SWA Agent
helm uninstall swa-agent -n "${SWA_NAMESPACE}"
