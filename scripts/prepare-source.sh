#!/bin/bash
# Clone or update the ImmortalWrt source tree, set up feeds.
# Run this once initially, again with --pull to sync.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${ROOT}/source"
BRANCH="${IWRT_BRANCH:-openwrt-24.10}"
REPO="${IWRT_REPO:-https://github.com/immortalwrt/immortalwrt.git}"

if [[ ! -d "${SRC}/.git" ]]; then
    echo ">>> Cloning ImmortalWrt (${BRANCH}) into ${SRC} ..."
    git clone --branch "${BRANCH}" --depth 1 "${REPO}" "${SRC}"
else
    if [[ "${1:-}" == "--pull" ]]; then
        echo ">>> Updating existing tree ..."
        git -C "${SRC}" fetch --depth 1 origin "${BRANCH}"
        git -C "${SRC}" reset --hard "origin/${BRANCH}"
    else
        echo ">>> Source tree exists — skip clone (use --pull to update)"
    fi
fi

echo ">>> Updating and installing feeds ..."
( cd "${SRC}" && ./scripts/feeds update -a && ./scripts/feeds install -a )

echo ">>> Source ready at ${SRC}"
echo ">>> Next: ./scripts/build.sh main-router  |  ./scripts/build.sh bypass-gateway"
