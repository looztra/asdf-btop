#!/usr/bin/env bash

set -euo pipefail

# TODO: Ensure this is the correct GitHub homepage where releases can be downloaded for btop.
GH_REPO="https://github.com/aristocratos/btop"
TOOL_NAME="btop"
TOOL_TEST="btop --version"

fail() {
  echo -e "asdf-$TOOL_NAME: $*"
  exit 1
}

curl_opts=(-fsSL)

# NOTE: You might want to remove this if btop is not hosted on GitHub releases.
if [ -n "${GITHUB_API_TOKEN:-}" ]; then
  curl_opts=("${curl_opts[@]}" -H "Authorization: token $GITHUB_API_TOKEN")
fi

sort_versions() {
  sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
    LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

list_github_tags() {
  git ls-remote --tags --refs "$GH_REPO" |
    grep -o 'refs/tags/.*' | cut -d/ -f3- |
    sed 's/^v//' # NOTE: You might want to adapt this sed to remove non-version strings from tags
}

list_all_versions() {
  # TODO: Adapt this. By default we simply list the tag names from GitHub releases.
  # Change this function if btop has other means of determining installable versions.
  list_github_tags
}

get_platform() {
  local arch kernel_name target

  arch=$(uname -m)
  kernel_name=$(uname -s | tr '[:upper:]' '[:lower:]')
  if [[ "${kernel_name}" == "darwin" ]]; then
    kernel_name=macos
  fi


  case $arch in
  armv5l) target="armv5l-linux-musleabi" ;;
  armv7l) target="armv7l-linux-musleabihf" ;;
  aarch64) target="aarch64-linux-musl" ;;
  arm64)
    if [[ "${kernel_name}" == "macos" ]]; then
      target="arm64-macos-bigsur"
    else
      target="unknown-arm64-target--${arch}--${kernel_name}"
    fi
    ;;
  x86_64)
    if [[ "${kernel_name}" == "linux" ]]; then
      target="x86_64-linux-musl"
    elif [[ "${kernel_name}" == "macos" ]]; then
      target="x86_64-macos-bigsur"
    else
      target="unknown-x86_64-target--${arch}--${kernel_name}"
    fi
    ;;
  i686) target="i686-linux-musl" ;;
  i386) target="i386-linux-musl" ;;
  *) target="unknown-target--${arch}--${kernel_name}" ;;
  esac
  echo "$target"
}

download_release() {
  local version filename url
  version="$1"
  filename="$2"

  # TODO: Adapt the release URL convention for btop
  url="$GH_REPO/releases/download/v${version}/${TOOL_NAME}-$(get_platform).tbz"

  echo "* Downloading $TOOL_NAME release $version from url [${}]..."
  curl "${curl_opts[@]}" -o "$filename" -C - "$url" || fail "Could not download $url"
}

install_version() {
  local install_type="$1"
  local version="$2"
  local install_path="$3"

  if [ "$install_type" != "version" ]; then
    fail "asdf-$TOOL_NAME supports release installs only"
  fi

  (
    mkdir -p "$install_path"
    cp -r "$ASDF_DOWNLOAD_PATH"/* "$install_path"

    # TODO: Asert btop executable exists.
    local tool_cmd
    tool_cmd="$(echo "$TOOL_TEST" | cut -d' ' -f1)"
    test -x "$install_path/bin/$tool_cmd" || fail "Expected $install_path/bin/$tool_cmd to be executable."

    echo "$TOOL_NAME $version installation was successful!"
  ) || (
    rm -rf "$install_path"
    fail "An error ocurred while installing $TOOL_NAME $version."
  )
}
