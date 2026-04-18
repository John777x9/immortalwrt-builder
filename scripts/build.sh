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
# Track start time so we can reject stale artifacts from previous builds.
BUILD_START_EPOCH=$(date +%s)

# CRITICAL: must capture real make exit code. Previous versions piped output
# or swallowed failures which produced false-positive "OK" with stale output.
set +e
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
BUILD_RC=$?
set -e

if [[ ${BUILD_RC} -ne 0 ]]; then
    echo
    echo "================ BUILD FAILED: ${ROLE} (rc=${BUILD_RC}) ================"
    # Wipe stale output so next consumer doesn't mistake old artifacts for new ones
    rm -f "${OUT}"/* 2>/dev/null || true
    exit ${BUILD_RC}
fi

echo ">>> Collecting artifacts (only files newer than build start) ..."
# Clear old OUT to prevent stale confusion
rm -f "${OUT}"/* 2>/dev/null || true

ARTDIRS=$(find "${SRC}/bin/targets" -mindepth 2 -maxdepth 2 -type d 2>/dev/null)
COUNT=0
for ARTDIR in $ARTDIRS; do
    for ext in img.gz vmdk itb bin; do
        for f in "${ARTDIR}"/*.${ext}; do
            [[ -f "$f" ]] || continue
            mt=$(stat -c %Y "$f")
            if [[ $mt -ge $((BUILD_START_EPOCH - 60)) ]]; then
                cp -v "$f" "${OUT}/" && COUNT=$((COUNT+1))
            fi
        done
    done
    for f in sha256sums profiles.json version.buildinfo; do
        [[ -f "${ARTDIR}/$f" ]] && cp -v "${ARTDIR}/$f" "${OUT}/" 2>/dev/null || true
    done
    for f in "${ARTDIR}"/*.manifest; do
        [[ -f "$f" ]] && cp -v "$f" "${OUT}/" 2>/dev/null || true
    done
done

if [[ $COUNT -eq 0 ]]; then
    echo "ERROR: no fresh artifacts produced by build (all files older than build start)"
    rm -f "${OUT}"/* 2>/dev/null || true
    exit 5
fi

echo
echo "================ BUILD OK: ${ROLE} — ${COUNT} fresh images ================"
ls -lh "${OUT}/"
