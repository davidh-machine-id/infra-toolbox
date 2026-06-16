#!/usr/bin/env bash
set -aeuo pipefail

SETUP_ENV_FILE="${PROJECT_ROOT}/setup.env"
if ! [[ -f "${SETUP_ENV_FILE}" ]]; then
	echo "ERROR: setup.env file does not exist, stopping."
	echo "       expected ${SETUP_ENV_FILE} to exist."
	exit 1
fi
source "${SETUP_ENV_FILE}"

ID_URL="$(curl -fsS "https://platform-discovery.cyberark.cloud/api/identity-endpoint/${CONJUR_TENANT}" | jq -r '.endpoint')"
if [[ -z "${ID_URL}" || "${ID_URL}" == "null" ]]; then
	echo "ERROR: failed to discover identity endpoint for tenant ${CONJUR_TENANT}" >&2
	exit 1
fi

# Extract host from identity URL.
host="${ID_URL#*://}"
host="${host%%/*}"
host="${host##*@}"
host="${host%%:*}"

ID_TENANT="${host%%.*}"
if [[ -z "${ID_TENANT}" ]]; then
	echo "ERROR: failed to parse tenant from identity URL: ${ID_URL}" >&2
	exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

IDUSER="$CONJUR_USER"
IDPASS="$CONJUR_PASS"
IDTENANTURL="https://${ID_TENANT}.id.cyberark.cloud"
IDTOKEN=$(bash $SCRIPT_DIR/idclient-authenticate.sh)

curl -fsS -X POST \
	"https://${CONJUR_TENANT}.secretsmgr.cyberark.cloud/api/authn-oidc/cyberark/conjur/authenticate" \
	-H 'Accept-Encoding: base64' \
	-H 'Content-Type: application/x-www-form-urlencoded' \
	--data-urlencode "id_token=${IDTOKEN}"
