#!/usr/bin/env bash
set -euo pipefail

REPO="https://github.com/gr8distance/mass-driver-cli.git"
BUILD_DIR="${TMPDIR:-/tmp}/mass-driver-cli-build"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"

# --- Check requirements ---

if ! command -v area51 >/dev/null 2>&1; then
  echo "error: area51 is required but not found."
  echo ""
  echo "Install area51 first:"
  echo "  curl -fsSL https://raw.githubusercontent.com/gr8distance/area51/main/install.sh | bash"
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  echo "error: git is required but not found."
  exit 1
fi

# --- Clone and build ---

echo "Cloning mass-driver-cli..."
rm -rf "$BUILD_DIR"
git clone --depth 1 "$REPO" "$BUILD_DIR"

echo "Installing dependencies..."
cd "$BUILD_DIR"
area51 install

echo "Building..."
area51 build

# --- Install ---

if [ -w "$INSTALL_DIR" ]; then
  cp bin/mass-driver-cli "$INSTALL_DIR/mass-driver"
else
  echo "Installing to $INSTALL_DIR (requires sudo)..."
  sudo cp bin/mass-driver-cli "$INSTALL_DIR/mass-driver"
fi

# --- Cleanup ---

rm -rf "$BUILD_DIR"

echo ""
echo "mass-driver installed to $INSTALL_DIR/mass-driver"
echo ""
echo "Get started:"
echo "  mass-driver new my-app"
echo "  cd my-app"
echo "  area51 install"
echo "  area51 run"
