#!/bin/bash
# Installs mermaid-ascii from GitHub releases

set -e

# Check if already installed
if command -v mermaid-ascii &> /dev/null; then
    echo "mermaid-ascii is already installed"
    mermaid-ascii --help | head -1
    exit 0
fi

# Check if installed in ~/.local/bin
if [ -x "$HOME/.local/bin/mermaid-ascii" ]; then
    echo "mermaid-ascii is already installed at ~/.local/bin/mermaid-ascii"
    exit 0
fi

echo "Installing mermaid-ascii..."

# Detect OS and architecture
OS=$(uname -s)
ARCH=$(uname -m)

# Map architecture names
case "$ARCH" in
    x86_64) ARCH="x86_64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

# Create temp directory
TMPDIR=$(mktemp -d)
cd "$TMPDIR"

# Get latest release URL
echo "Fetching latest release..."
DOWNLOAD_URL=$(curl -s https://api.github.com/repos/AlexanderGrooff/mermaid-ascii/releases/latest | \
    grep "browser_download_url.*${OS}_${ARCH}.tar.gz" | \
    cut -d '"' -f 4)

if [ -z "$DOWNLOAD_URL" ]; then
    echo "Could not find release for ${OS}_${ARCH}"
    echo "You may need to build from source: https://github.com/AlexanderGrooff/mermaid-ascii"
    rm -rf "$TMPDIR"
    exit 1
fi

echo "Downloading from: $DOWNLOAD_URL"
curl -sL "$DOWNLOAD_URL" -o mermaid-ascii.tar.gz

echo "Extracting..."
tar xzf mermaid-ascii.tar.gz

# Install to ~/.local/bin
mkdir -p "$HOME/.local/bin"
mv mermaid-ascii "$HOME/.local/bin/"
chmod +x "$HOME/.local/bin/mermaid-ascii"

# Cleanup
cd /
rm -rf "$TMPDIR"

echo "Installed mermaid-ascii to ~/.local/bin/mermaid-ascii"
echo ""
echo "Ensure ~/.local/bin is in your PATH:"
echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
