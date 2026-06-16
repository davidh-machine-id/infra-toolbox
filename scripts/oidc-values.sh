#!/bin/bash
set -aeuo pipefail

SETUP_ENV_FILE="${PROJECT_ROOT}/setup.env"
if ! [[ -f "${SETUP_ENV_FILE}" ]]; then
	echo "ERROR: setup.env file does not exist, stopping."
	echo "       expected ${SETUP_ENV_FILE} to exist."
	exit 1
fi
source "${SETUP_ENV_FILE}"

export TOK=$(bash ${PROJECT_ROOT}/scripts/get-conjur-token.sh)
curl -sS -X GET "$CONJUR_APPLIANCE_URL/swa/trust-domains/${SWA_TRUST_DOMAIN}" \
	-H "Authorization: Token token=\"$TOK\"" \
	-H "Accept: application/x.secretsmgr.v2+json" \
	-H "Content-Type: application/json" |
	jq .
