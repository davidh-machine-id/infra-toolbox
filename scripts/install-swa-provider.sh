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

SWA_ISSUER=$(kubectl get --raw /.well-known/openid-configuration | jq -r .issuer)
SWA_PUBLIC_KEYS=$(kubectl get --raw /openid/v1/jwks | jq -c '{type:"jwks",value:.}')
SWA_K8S_DIR="${PROJECT_ROOT}/terraform/environments/swa-provider"
SERVER_GROUP_NAME="${SWA_SERVER_GROUP_NAME}"
SERVER_NAME="${SWA_SERVER_NAME}"

echo "public_keys=$SWA_PUBLIC_KEYS"
echo "trust_domain_name=$SWA_TRUST_DOMAIN"
echo "jwt_issuer=$SWA_ISSUER"
echo "cluster_name=$SWA_CLUSTER_NAME"
echo "SWA dir=$SWA_K8S_DIR"

cd "${SWA_K8S_DIR}"
terraform init
terraform apply -auto-approve \
	-var="public_keys=$SWA_PUBLIC_KEYS" \
	-var="trust_domain_name=$SWA_TRUST_DOMAIN" \
	-var="jwt_issuer=$SWA_ISSUER" \
	-var="cluster_name=$SWA_CLUSTER_NAME" \
	-var="node_group_name=$SWA_NODEGROUP" \
	-var="server_group_name=$SERVER_GROUP_NAME" \
	-var="server_name=$SERVER_NAME" \
	-var="workload_namespace=$WORKLOAD_NAMESPACE"
