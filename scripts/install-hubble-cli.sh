#!/usr/bin/env bash

# Get the latest stable Hubble version and set architecture
HUBBLE_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/hubble/master/stable.txt)
HUBBLE_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then
  HUBBLE_ARCH=arm64
fi

# Download the Hubble tarball and checksum
curl -L --fail --remote-name-all \
  https://github.com/cilium/hubble/releases/download/${HUBBLE_VERSION}/hubble-linux-${HUBBLE_ARCH}.tar.gz{,.sha256sum}

# Validate the download
sha256sum --check hubble-linux-${HUBBLE_ARCH}.tar.gz.sha256sum

# Install the binary
sudo tar xzf hubble-linux-${HUBBLE_ARCH}.tar.gz -C /usr/local/bin

# Cleanup
rm hubble-linux-${HUBBLE_ARCH}.tar.gz{,.sha256sum}
