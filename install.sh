#!/bin/sh
# Installs the snaplake CLI (INSTALL_GUIDE.md):
#
#   curl -fsSL https://raw.githubusercontent.com/ajith-joseph/snaplake-install/main/install.sh | sh
#
# Served from the public repo ajith-joseph/snaplake-install, which each tagged release refreshes from this file
# (.github/workflows/release.yml); edit it here, never there.
#
# It downloads the native binary a release published to GHCR (`snaplake publishCli`, an OCI artifact
# <registry>/snaplake/cli:<tag> holding one gzipped file), checks its sha256 against the registry's digest, and puts it
# on the PATH as `snaplake`. Nothing else is installed or changed.
#
# Environment (all optional):
#   SNAPLAKE_VERSION      release tag, e.g. v0.21.0 (default: latest)
#   SNAPLAKE_REGISTRY     where releases are published (default: ghcr.io/ajithj2010)
#   SNAPLAKE_INSTALL_DIR  where to put the binary (default: /usr/local/bin as root or when writable, else ~/.local/bin)
#
# Linux x86_64 with glibc 2.34 or newer (Ubuntu 22.04+, Debian 12+, RHEL/Rocky/Alma 9+).
set -eu

# Everything runs from main, called on the last line, so a download cut off halfway runs nothing.
main() {
    version="${SNAPLAKE_VERSION:-latest}"
    registry="${SNAPLAKE_REGISTRY:-ghcr.io/ajithj2010}"
    host="${registry%%/*}"
    repository="${registry#*/}/snaplake/cli"

    check_platform
    need curl
    need gzip
    sha256=$(sha256_tool)

    install_dir="${SNAPLAKE_INSTALL_DIR:-$(default_install_dir)}"
    mkdir -p "$install_dir" || fail "cannot create $install_dir (set SNAPLAKE_INSTALL_DIR)"
    [ -w "$install_dir" ] || fail "cannot write to $install_dir (run as root, or set SNAPLAKE_INSTALL_DIR)"

    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT INT TERM

    say "Downloading snaplake $version from $registry"
    token=$(curl -fsSL "https://$host/token?scope=repository:$repository:pull&service=$host" \
        | sed -n 's/.*"token" *: *"\([^"]*\)".*/\1/p') || true
    [ -n "$token" ] || fail "could not get a pull token from $host for $repository (is the package public?)"

    manifest=$(curl -fsSL -H "Authorization: Bearer $token" \
        -H "Accept: application/vnd.oci.image.manifest.v1+json" \
        "https://$host/v2/$repository/manifests/$version") \
        || fail "no release $version at $registry/snaplake/cli"
    digest=$(printf '%s' "$manifest" | tr -d ' \n\r\t' \
        | sed -n 's/.*"layers":\[{[^]]*"digest":"\(sha256:[0-9a-f]\{64\}\)".*/\1/p')
    [ -n "$digest" ] || fail "unexpected manifest for $registry/snaplake/cli:$version"

    curl -fL --progress-bar -H "Authorization: Bearer $token" -o "$tmp/snaplake.gz" \
        "https://$host/v2/$repository/blobs/$digest" || fail "download failed"
    actual="sha256:$($sha256 "$tmp/snaplake.gz" | cut -d' ' -f1)"
    [ "$actual" = "$digest" ] || fail "checksum mismatch: expected $digest, got $actual"

    gzip -dc "$tmp/snaplake.gz" > "$tmp/snaplake"
    chmod 755 "$tmp/snaplake"
    "$tmp/snaplake" --version > /dev/null 2>&1 \
        || fail "the downloaded binary does not run here (glibc 2.34+ needed; this host has $(glibc_version))"
    mv -f "$tmp/snaplake" "$install_dir/snaplake"

    say "Installed $("$install_dir/snaplake" --version) to $install_dir/snaplake"
    case ":$PATH:" in
        *":$install_dir:"*) ;;
        *) say "Add $install_dir to your PATH:  export PATH=\"$install_dir:\$PATH\"" ;;
    esac
    cat <<EOF

Next:
  snaplake init        # writes datalake-package-install.yml here; set the host and platform-domain
  snaplake install     # installs the platform (see INSTALL_GUIDE.md)
EOF
}

check_platform() {
    [ "$(uname -s)" = Linux ] || fail "snaplake runs on Linux only (this is $(uname -s))"
    case "$(uname -m)" in
        x86_64 | amd64) ;;
        *) fail "snaplake is built for x86_64 only (this is $(uname -m))" ;;
    esac
}

glibc_version() {
    ldd --version 2> /dev/null | head -n1 | sed -n 's/.* \([0-9][0-9]*\.[0-9][0-9]*\)$/glibc \1/p' | grep . || echo "no glibc"
}

default_install_dir() {
    if [ "$(id -u)" = 0 ] || [ -w /usr/local/bin ]; then
        echo /usr/local/bin
    else
        echo "$HOME/.local/bin"
    fi
}

sha256_tool() {
    if command -v sha256sum > /dev/null 2>&1; then
        echo sha256sum
    elif command -v shasum > /dev/null 2>&1; then
        echo "shasum -a 256"
    else
        fail "need sha256sum or shasum"
    fi
}

need() {
    command -v "$1" > /dev/null 2>&1 || fail "need $1"
}

say() {
    printf '%s\n' "$*"
}

fail() {
    printf 'snaplake install: %s\n' "$*" >&2
    exit 1
}

main "$@"
