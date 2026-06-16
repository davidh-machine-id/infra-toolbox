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
helm upgrade --install swa-agent ./swa-agent \
	--namespace swa-system \
	--set image.repository=${SWA_IMAGE_REGISTRY}/swa-agent \
	--set image.tag=${SWA_AGENT_IMAGE_TAG} \
	--set trustDomain.name=${SWA_TRUST_DOMAIN} \
	--set server.address=swa-server.swa-system.svc.cluster.local:8443 \
	--set podLabels.swa_nodegroup=${SWA_NODEGROUP} \
	--set nodeAttestor.type=k8s_psat \
	--set nodeAttestor.k8s_psat.cluster=${SWA_CLUSTER_NAME} \
	--set workloadAttestors[0].type=k8s \
	--set workloadAttestors[0].config.skipKubeletVerification=true \
	--set workloadAttestors[0].config.nodeNameEnv=SWA_NODE_NAME \
	--set bootstrap.bundleSourceUrl=${SWA_CONJUR_APPLIANCE_URL}/api/swa/trust-domains/${SWA_TRUST_DOMAIN}/.well-known/ca-bundles
