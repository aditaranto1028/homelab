#!/usr/bin/env bash

# Determine the latest stable version and target architecture
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then
  CLI_ARCH=arm64
fi

# Download the tarball and its SHA-256 checksum
curl -L --fail --remote-name-all \
  https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}

# Verify the checksum before extraction
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum

# Extract and install the binary
sudo tar xzvf cilium-linux-${CLI_ARCH}.tar.gz -C /usr/local/bin

# Remove downloaded files
rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
