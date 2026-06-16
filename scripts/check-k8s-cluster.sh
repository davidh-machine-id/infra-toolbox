#!/usr/bin/env bash
set -aeuo pipefail

SETUP_ENV_FILE="${PROJECT_ROOT}/setup.env"
if ! [[ -f "${SETUP_ENV_FILE}" ]]; then
	echo "ERROR: setup.env file does not exist, stopping."
	echo "       expected ${SETUP_ENV_FILE} to exist."
	exit 1
fi
source "${SETUP_ENV_FILE}"

# shellcheck disable=SC1090
_auto_yes="${SWA_AUTO_YES:-no}"

function prompt_continue() {
	if [[ "$_auto_yes" == "yes" ]]; then
		return 0
	fi
	read -p "To continue, type 'yes': " confirmation
	if [[ "$confirmation" != "yes" ]]; then
		exit 1
	fi
}

# Assume kubectl current-context is set to the desired target cluster
# Note: kind clusters have "kind-" prefix added to the context,
#       this prefix is removed to render the real cluster name"
_derived_cluster_name=$(kubectl config view -o json | jq -r '
  . as $root 
  | .["current-context"] as $ctx 
  | $root.contexts[] 
  | select(.name == $ctx) 
  | .context.cluster 
  | sub("^kind-"; "")
')

if [[ "$_derived_cluster_name" != "$SWA_CLUSTER_NAME" ]]; then
	echo "WARN: value in SWA_CLUSTER_NAME ($SWA_CLUSTER_NAME) does not match what is reported by kubectl ($_derived_cluster_name)"
	echo "NOTE: if using a kind cluster the cluster name shown is without the 'kind-' prefix."
	echo
	prompt_continue
fi

