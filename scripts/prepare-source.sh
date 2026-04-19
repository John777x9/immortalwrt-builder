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

# Apply local patches against the upstream source tree.
# These fix upstream bugs that block OUR build (typically pending-fix bugs
# that show up in the latest snapshot of openwrt-24.10).
PATCH_DIR="${ROOT}/patches"
if [[ -d "${PATCH_DIR}" ]] && ls "${PATCH_DIR}"/*.patch >/dev/null 2>&1; then
    echo ">>> Applying local patches from ${PATCH_DIR} ..."
    for p in "${PATCH_DIR}"/*.patch; do
        # Idempotent: try apply, skip if already applied
        if git -C "${SRC}" apply --check "$p" 2>/dev/null; then
            git -C "${SRC}" apply "$p"
            echo "  applied: $(basename $p)"
        else
            echo "  skip (already applied or N/A): $(basename $p)"
        fi
    done
fi

echo ">>> Source ready at ${SRC}"
echo ">>> Next: ./scripts/build.sh main-router  |  ./scripts/build.sh bypass-gateway"
