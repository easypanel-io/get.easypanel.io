#!/bin/sh
set -eu

release_repo="easypanel-io/cli"
version="${EASYPANEL_CLI_VERSION:-latest}"

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

for command_name in curl tar; do
  if ! command_exists "$command_name"; then
    echo "Error: $command_name is required" >&2
    exit 1
  fi
done

case "$(uname -s)" in
  Darwin) os="Darwin" ;;
  Linux) os="Linux" ;;
  *)
    echo "Error: unsupported operating system $(uname -s)" >&2
    exit 1
    ;;
esac

case "$(uname -m)" in
  x86_64|amd64) arch="x86_64" ;;
  arm64|aarch64) arch="arm64" ;;
  *)
    echo "Error: unsupported architecture $(uname -m)" >&2
    exit 1
    ;;
esac

asset="easypanel_${os}_${arch}.tar.gz"
if [ "$version" = "latest" ]; then
  download_base="https://github.com/${release_repo}/releases/latest/download"
else
  version="${version#v}"
  download_base="https://github.com/${release_repo}/releases/download/v${version}"
fi
if [ -n "${EASYPANEL_CLI_DOWNLOAD_BASE:-}" ]; then
  download_base="${EASYPANEL_CLI_DOWNLOAD_BASE%/}"
fi

temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/easypanel-cli.XXXXXX")"
trap 'rm -rf "$temp_dir"' EXIT INT TERM

echo "Downloading Easypanel CLI ${version} for ${os}/${arch}..."
curl -fsSL "${download_base}/${asset}" -o "${temp_dir}/${asset}"
curl -fsSL "${download_base}/checksums.txt" -o "${temp_dir}/checksums.txt"

awk -v asset="$asset" '$2 == asset { print }' \
  "${temp_dir}/checksums.txt" >"${temp_dir}/asset.checksum"
if [ ! -s "${temp_dir}/asset.checksum" ]; then
  echo "Error: checksum for $asset is missing" >&2
  exit 1
fi

if command_exists sha256sum; then
  (cd "$temp_dir" && sha256sum -c asset.checksum)
elif command_exists shasum; then
  (cd "$temp_dir" && shasum -a 256 -c asset.checksum)
else
  echo "Error: sha256sum or shasum is required" >&2
  exit 1
fi

tar -xzf "${temp_dir}/${asset}" -C "$temp_dir"

if [ -n "${EASYPANEL_CLI_INSTALL_DIR:-}" ]; then
  install_dir="$EASYPANEL_CLI_INSTALL_DIR"
elif [ "$(id -u)" -eq 0 ] || { [ -d /usr/local/bin ] && [ -w /usr/local/bin ]; }; then
  install_dir="/usr/local/bin"
else
  install_dir="${HOME}/.local/bin"
fi

mkdir -p "$install_dir"
install -m 0755 "${temp_dir}/easypanel" "${install_dir}/easypanel"
install -m 0755 "${temp_dir}/ep" "${install_dir}/ep"

echo "Installed easypanel and ep in ${install_dir}"
case ":${PATH}:" in
  *:"${install_dir}":*) ;;
  *)
    echo "Add ${install_dir} to PATH, then open a new terminal." >&2
    ;;
esac
"${install_dir}/easypanel" version
