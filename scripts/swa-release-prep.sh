#!/usr/bin/env bash
set -euo pipefail

SETUP_ENV_FILE="${PROJECT_ROOT}/setup.env"
if ! [[ -f "${SETUP_ENV_FILE}" ]]; then
	echo "ERROR: setup.env file does not exist, stopping."
	echo "       expected ${SETUP_ENV_FILE} to exist."
	exit 1
fi
source "${SETUP_ENV_FILE}"

swa_release_dir="$PROJECT_ROOT/swa-release"
helm_dir="$swa_release_dir/helm"
tf_provider_dir="$swa_release_dir/terraform-provider"
terraform_dir="$PROJECT_ROOT/terraform"

# ============================================================
# Tasks to complete:
# - locate helm dir (should be under ./swa-release/helm)
# - untar helm agent and server files
# - install terraform provider using ./swa-release/install-terraform-provider.sh
# - extract tf provider version
# - compare tf provider version in tf code that uses the swa provider to ensure the tf code is using the right version
# ============================================================

# --- OS detection ---
detect_os() {
	case "$(uname -s)" in
	Darwin) echo "darwin" ;;
	Linux) echo "linux" ;;
	MINGW* | MSYS* | CYGWIN*)
		echo "Windows is not supported by this script. Use install-terraform-provider.ps1 instead." >&2
		exit                                                                                    1
		;;
	*)
		echo "unsupported OS: $(uname -s)" >&2
		exit        1
		;;
	esac
}

# --- Arch detection ---
detect_arch() {
	case "$(uname -m)" in
	x86_64) echo "amd64" ;;
	aarch64 | arm64) echo "arm64" ;;
	*)
		echo "unsupported arch: $(uname -m)" >&2
		exit          1
		;;
	esac
}
GOOS="$(detect_os)"
GOARCH="$(detect_arch)"

# ============================================================
# Task 1: Validate Prerequisites
# ============================================================
if [ ! -d "$swa_release_dir" ]; then
	echo "✗ swa-release/ directory not found at $swa_release_dir"
	exit 1
fi

# ============================================================
# Task 2: Extract Helm Charts
# ============================================================

# Extract swa-agent helm chart
agent_tgz=$(find "$helm_dir" -maxdepth 1 -name "swa-agent*.tgz" -type f | head -1)
if [ -z "$agent_tgz" ]; then
	echo "✗ swa-agent*.tgz not found in $helm_dir"
	exit 1
fi

rm -rf "$helm_dir/swa-agent"
mkdir -p "$helm_dir/swa-agent"
tar -xzf "$agent_tgz" -C "$helm_dir/swa-agent" --strip-components=1
echo "Extracted: $(basename "$agent_tgz")"

# Extract swa-server helm chart
server_tgz=$(find "$helm_dir" -maxdepth 1 -name "swa-server*.tgz" -type f | head -1)
if [ -z "$server_tgz" ]; then
	echo "✗ swa-server*.tgz not found in $helm_dir"
	exit 1
fi

rm -rf "$helm_dir/swa-server"
mkdir -p "$helm_dir/swa-server"
tar -xzf "$server_tgz" -C "$helm_dir/swa-server" --strip-components=1
echo "Extracted: $(basename "$server_tgz")"

# ============================================================
# Task 3: Install Terraform Provider
# ============================================================
if [ ! -f "$swa_release_dir/install-terraform-provider.sh" ]; then
	echo "✗ install-terraform-provider.sh not found in $swa_release_dir"
	exit 1
fi

if ! bash "$swa_release_dir/install-terraform-provider.sh"; then
	echo "✗ Failed to install Terraform provider"
	exit 1
fi
echo "Installed: Terraform provider"

# ============================================================
# Task 4: Extract Provider Version
# ============================================================

provider_dir_path=$(find $swa_release_dir -name "terraform-provider-swa_*" -type d | head -1)
provider_dir=$(basename $provider_dir_path)
provider_suffix=${provider_dir#terraform-provider-swa_}
provider_version=$(echo $provider_suffix | awk -F_ '{print $1}')

if [ -z "$provider_version" ]; then
	echo "✗ Could not extract version from provider binary: $provider_binary_name"
	exit 1
fi

# Validate provider installation
provider_install_dir="$HOME/.terraform.d/plugins/registry.terraform.io/cyberark/swa"
if [ ! -d "$provider_install_dir" ]; then
	echo "✗ Provider not installed at $provider_install_dir"
	exit 1
fi

# Check ~/.terraformrc and display provider version
if [ -f "$HOME/.terraformrc" ]; then
	if grep -q "cyberark/swa" "$HOME/.terraformrc"; then
		echo "Provider version: $provider_version"
	fi
else
	echo "⚠ ~/.terraformrc not found (optional)"
fi

# ============================================================
# Task 5: Extract Terraform Code Version
# ============================================================

# Search for required_providers block with swa provider and extract version
# Also capture the file path for error reporting
tf_version=""
tf_file_path=""

while read -r tf_file; do
	if [ -n "$tf_file" ]; then
		version=$(grep -A10 'cyberark/swa' "$tf_file" 2>/dev/null | grep 'version' | sed -E 's/.*version[[:space:]]*=[[:space:]]*"([^"]*)".*/\1/' | head -1)
		if [ -n "$version" ]; then
			tf_version="$version"
			tf_file_path="$tf_file"
			break
		fi
	fi
done < <(grep -r "source.*cyberark/swa" "$terraform_dir/modules" "$terraform_dir/environments" 2>/dev/null | sed 's/:.*source.*//')

if [ -z "$tf_version" ]; then
	echo "WARNING: Could not find cyberark/swa provider version in Terraform code"
	exit 0
fi

echo "Terraform version: $tf_version (from: ./${tf_file_path#$PROJECT_ROOT/})"

# ============================================================
# Task 6: Compare Versions
# ============================================================

if [ "$provider_version" != "$tf_version" ]; then
	echo "✗ Version mismatch!"
	echo "  Provider version: $provider_version"
	echo "  Terraform requires: $tf_version"
	echo "  Update in: ./${tf_file_path#$PROJECT_ROOT/}"
	exit 1
fi

echo "✓ Versions match"

IMAGE_BASE="$PROJECT_ROOT/swa-release/container-images"
IMAGE_AGENT="$(find $IMAGE_BASE -maxdepth 1 -type f -name 'swa-agent-*-'${GOARCH}'*.tar' | sort | head -1)"
IMAGE_SERVER="$(find $IMAGE_BASE -maxdepth 1 -type f -name 'swa-server-*-'${GOARCH}'*.tar' | sort | head -1)"

if [ -z "$IMAGE_AGENT" ]; then
	echo "ERROR: could not find swa-agent container image."
	exit 1
fi
if [ -z "$IMAGE_SERVER" ]; then
	echo "ERROR: could not find swa-server container image."
	exit 1
fi
# Extract tag from agent image filename
# e.g., swa-agent-0.0.0-SNAPSHOT-arm64v8.tar -> 0.0.0-SNAPSHOT-arm64v8
AGENT_FILENAME=$(basename "$IMAGE_AGENT")
SWA_AGENT_IMAGE_TAG=$(echo "$AGENT_FILENAME" | sed -E 's/swa-agent-(.+)\.tar/\1/')

# Extract tag from server image filename
# e.g., swa-server-0.0.0-SNAPSHOT-arm64v8.tar -> 0.0.0-SNAPSHOT-arm64v8
SERVER_FILENAME=$(basename "$IMAGE_SERVER")
SWA_SERVER_IMAGE_TAG=$(echo "$SERVER_FILENAME" | sed -E 's/swa-server-(.+)\.tar/\1/')

echo "Extracted container tags:"
echo "  Agent tag:  $SWA_AGENT_IMAGE_TAG"
echo "  Server tag: $SWA_SERVER_IMAGE_TAG"

# Update setup.env with extracted tags
sed -i.bak "s|^SWA_SERVER_IMAGE_TAG=.*|SWA_SERVER_IMAGE_TAG=\"$SWA_SERVER_IMAGE_TAG\"|" "$SETUP_ENV_FILE"
sed -i.bak "s|^SWA_AGENT_IMAGE_TAG=.*|SWA_AGENT_IMAGE_TAG=\"$SWA_AGENT_IMAGE_TAG\"|" "$SETUP_ENV_FILE"

sed -i.bak "s|^SWA_SERVER_CONTAINER_IMAGE=.*|SWA_SERVER_CONTAINER_IMAGE=\"$IMAGE_SERVER\"|" "$SETUP_ENV_FILE"
sed -i.bak "s|^SWA_AGENT_CONTAINER_IMAGE=.*|SWA_AGENT_CONTAINER_IMAGE=\"$IMAGE_AGENT\"|" "$SETUP_ENV_FILE"

echo "Updated $SETUP_ENV_FILE with swa image and container values"
