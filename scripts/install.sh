#!/bin/sh
set -eu

REPOSITORY='nguyenthang1597/dart_stylizer'
VERSION='latest'
INSTALL_DIR=${DART_STYLIZER_INSTALL_DIR:-"$HOME/.local/bin"}

usage() {
  cat <<'EOF'
Install or update the Dart Stylizer standalone executable.

Usage: install.sh [--version vX.Y.Z] [--install-dir PATH]

Options:
  --version VERSION     Install a specific release (default: latest)
  --install-dir PATH    Install directory (default: ~/.local/bin)
  -h, --help            Show this help

Set DART_STYLIZER_INSTALL_DIR to choose a default install directory.
EOF
}

fail() {
  printf 'install.sh: %s\n' "$1" >&2
  exit 1
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --version)
      [ "$#" -ge 2 ] || fail 'missing value for --version'
      VERSION=$2
      shift 2
      ;;
    --install-dir)
      [ "$#" -ge 2 ] || fail 'missing value for --install-dir'
      INSTALL_DIR=$2
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown option: $1 (use --help for usage)"
      ;;
  esac
done

if [ "$VERSION" != 'latest' ]; then
  printf '%s\n' "$VERSION" | grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+$' || \
    fail 'version must be latest or a stable tag such as v0.2.0'
fi

command -v curl >/dev/null 2>&1 || fail 'curl is required'
if command -v sha256sum >/dev/null 2>&1; then
  checksum_command='sha256sum'
elif command -v shasum >/dev/null 2>&1; then
  checksum_command='shasum'
else
  fail 'sha256sum or shasum is required to verify the download'
fi

operating_system=$(uname -s)
architecture=$(uname -m)
case "$operating_system/$architecture" in
  Linux/x86_64|Linux/amd64)
    asset='dart_stylizer-linux-X64'
    ;;
  Darwin/arm64|Darwin/aarch64)
    asset='dart_stylizer-macos-ARM64'
    ;;
  *)
    fail "no prebuilt release is available for $operating_system/$architecture"
    ;;
esac

if [ "$VERSION" = 'latest' ]; then
  download_base="https://github.com/$REPOSITORY/releases/latest/download"
else
  download_base="https://github.com/$REPOSITORY/releases/download/$VERSION"
fi

mkdir -p "$INSTALL_DIR" || fail "cannot create install directory: $INSTALL_DIR"
temp_dir=$(mktemp -d) || fail 'could not create a temporary directory'
staged_file=''
cleanup() {
  rm -rf "$temp_dir"
  if [ -n "$staged_file" ]; then
    rm -f "$staged_file"
  fi
}
trap cleanup EXIT HUP INT TERM

curl --fail --location --silent --show-error --retry 3 \
  "$download_base/$asset" -o "$temp_dir/$asset" || \
  fail "could not download $asset for $VERSION"
curl --fail --location --silent --show-error --retry 3 \
  "$download_base/SHA256SUMS" -o "$temp_dir/SHA256SUMS" || \
  fail "could not download checksums for $VERSION"

expected_checksum=$(awk -v filename="$asset" '$2 == filename { print $1; exit }' \
  "$temp_dir/SHA256SUMS")
[ -n "$expected_checksum" ] || fail "checksum entry not found for $asset"
if [ "$checksum_command" = 'sha256sum' ]; then
  actual_checksum=$(sha256sum "$temp_dir/$asset" | awk '{ print $1 }')
else
  actual_checksum=$(shasum -a 256 "$temp_dir/$asset" | awk '{ print $1 }')
fi
[ "$actual_checksum" = "$expected_checksum" ] || \
  fail "checksum verification failed for $asset"

staged_file=$(mktemp "$INSTALL_DIR/.dart_stylizer.XXXXXX") || \
  fail "cannot stage executable in $INSTALL_DIR"
cp "$temp_dir/$asset" "$staged_file" || fail 'could not stage executable'
chmod 755 "$staged_file" || fail 'could not make the executable runnable'
mv -f "$staged_file" "$INSTALL_DIR/dart_stylizer" || \
  fail "could not install executable in $INSTALL_DIR"
staged_file=''

printf 'Installed Dart Stylizer (%s) to %s/dart_stylizer\n' \
  "$VERSION" "$INSTALL_DIR"
printf 'Run the same command again to update to a newer release.\n'
