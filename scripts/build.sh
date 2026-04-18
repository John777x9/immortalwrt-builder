#!/bin/bash
# Build a firmware variant inside the iwrt-builder Docker container.
# Role is auto-validated by checking that configs/<role>.config exists.
#
# Usage:  ./scripts/build.sh <role>  [JOBS=N]
#   role = any name with a matching configs/<role>.config

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${ROOT}/source"
ROLE="${1:?Usage: $0 <role>   (where configs/<role>.config exists)}"
shift || true

CONFIG="${ROOT}/configs/${ROLE}.config"
FILES_COMMON="${ROOT}/files/common"
FILES_ROLE="${ROOT}/files/${ROLE}"
OUT="${ROOT}/output/${ROLE}"
CCACHE="${ROOT}/.ccache"
JOBS="${JOBS:-$(nproc)}"
IMAGE="iwrt-builder:24.10"

[[ -d "${SRC}" ]] || { echo "ERROR: source not prepared. Run scripts/prepare-source.sh first."; exit 3; }
[[ -f "${CONFIG}" ]] || { echo "ERROR: missing ${CONFIG} (no such role)"; exit 4; }

echo ">>> Cleaning previous baked-in /files/ overlay ..."
rm -rf "${SRC}/files"
mkdir -p "${SRC}/files"

echo ">>> Layering common + role files into source/files ..."
[[ -d "${FILES_COMMON}" ]] && cp -a "${FILES_COMMON}/." "${SRC}/files/"
[[ -d "${FILES_ROLE}"   ]] && cp -a "${FILES_ROLE}/."   "${SRC}/files/"

# Stamp build date into banner
BUILDDATE="$(date -u +%Y-%m-%dT%H:%MZ)"
[[ -f "${SRC}/files/etc/banner" ]] && sed -i "s|%BUILDDATE%|${BUILDDATE}|g" "${SRC}/files/etc/banner" || true
[[ -f "${SRC}/files/etc/uci-defaults/99-common-hardening" ]] && sed -i "s|%BUILDDATE%|${BUILDDATE}|g" "${SRC}/files/etc/uci-defaults/99-common-hardening" || true

echo ">>> Marking uci-defaults executable ..."
chmod +x "${SRC}/files/etc/uci-defaults/"* 2>/dev/null || true

echo ">>> Installing diffconfig as .config ..."
cp "${CONFIG}" "${SRC}/.config"

mkdir -p "${OUT}" "${CCACHE}"

echo ">>> Running build for role=${ROLE}, jobs=${JOBS} ..."
docker run --rm \
    --name "iwrt-build-${ROLE}" \
    -u "$(id -u):$(id -g)" \
    -v "${SRC}:/home/builder/source" \
    -v "${CCACHE}:/home/builder/.ccache" \
    -e CCACHE_DIR=/home/builder/.ccache \
    -e BUILD_ROLE="${ROLE}" \
    -e BUILD_DATE="${BUILDDATE}" \
    -w /home/builder/source \
    "${IMAGE}" \
    bash -c "
        set -e
        echo '--- defconfig (expanding diffconfig) ---'
        make defconfig
        echo '--- download (parallel) ---'
        make download -j8 V=s 2>&1 | tail -40 || true
        echo '--- compile ---'
        make -j${JOBS} V=s
    "

echo ">>> Collecting artifacts ..."
# Auto-detect target dir (x86/64, mediatek/filogic, etc)
ARTDIRS=$(find "${SRC}/bin/targets" -mindepth 2 -maxdepth 2 -type d 2>/dev/null)
for ARTDIR in $ARTDIRS; do
    cp -v "${ARTDIR}"/*.img.gz "${OUT}/" 2>/dev/null || true
    cp -v "${ARTDIR}"/*.vmdk   "${OUT}/" 2>/dev/null || true
    cp -v "${ARTDIR}"/*.itb    "${OUT}/" 2>/dev/null || true
    cp -v "${ARTDIR}"/*.bin    "${OUT}/" 2>/dev/null || true
    cp -v "${ARTDIR}"/sha256sums "${OUT}/sha256sums" 2>/dev/null || true
    cp -v "${ARTDIR}"/profiles.json "${OUT}/profiles.json" 2>/dev/null || true
    cp -v "${ARTDIR}"/version.buildinfo "${OUT}/" 2>/dev/null || true
    cp -v "${ARTDIR}"/*.manifest "${OUT}/" 2>/dev/null || true
done

if ls "${OUT}"/* >/dev/null 2>&1; then
    echo
    echo "================ BUILD OK: ${ROLE} ================"
    ls -lh "${OUT}/"
else
    echo "ERROR: no artifacts collected"
    exit 5
fi
