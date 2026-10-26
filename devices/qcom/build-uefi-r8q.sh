#!/bin/sh
set -eu
SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
REPO_ROOT="$(CDPATH='' cd -- "${SCRIPT_DIR}/../.." && pwd)"
if [ -z "${MUSIL:-}" ]; then
    echo "ERROR: set MUSIL to a Mu-Silicium checkout" >&2
    exit 1
fi
if [ ! -d "${MUSIL}" ]; then
    echo "ERROR: Mu-Silicium checkout not found: ${MUSIL}" >&2
    exit 1
fi
MUSIL="$(CDPATH='' cd -- "${MUSIL}" && pwd)"
DTB="${DTB:-${REPO_ROOT}/devices/qcom/overlays/r8q/usr/lib/linux-image-qcom/qcom/sm8250-samsung-r8q.dtb}"
if [ ! -s "${DTB}" ]; then
    echo "ERROR: r8q DTB not found or empty: ${DTB}" >&2
    exit 1
fi
FDF="${MUSIL}/Platforms/Samsung/r8qPkg/r8q.fdf"
DTB_DEST="${MUSIL}/Platforms/Samsung/r8qPkg/FdtBlob/sm8250-samsung-r8q.dtb"
if [ ! -f "${FDF}" ] || [ ! -d "$(dirname "${DTB_DEST}")" ]; then
    echo "ERROR: Mu-Silicium checkout is missing the r8q platform files" >&2
    exit 1
fi
if ! grep -Eq '^[[:space:]]*INF EmbeddedPkg/Drivers/DtPlatformDxe/DtPlatformDxe[.]inf' "${FDF}" ||
    ! grep -Eq '^[[:space:]]*FILE FREEFORM = 25462CDA-221F-47DF-AC1D-259CFAA4E326' "${FDF}" ||
    ! grep -Eq '^[[:space:]]*SECTION RAW = r8qPkg/FdtBlob/sm8250-samsung-r8q[.]dtb' "${FDF}"; then
    echo "ERROR: enable the Device Tree FREEFORM block in ${FDF} before building" >&2
    exit 1
fi
VENV="${VENV:-$(dirname "${MUSIL}")/.venv}"
PYTHON="${PYTHON:-${VENV}/bin/python}"
case "${PYTHON}" in
    */*)
        case "${PYTHON}" in
            /*) ;;
            *) PYTHON="${PWD}/${PYTHON}" ;;
        esac
        if [ ! -x "${PYTHON}" ]; then
            echo "ERROR: Python executable not found: ${PYTHON} (set PYTHON or VENV)" >&2
            exit 1
        fi
        ;;
    *)
        PYTHON="$(command -v "${PYTHON}" || true)"
        if [ -z "${PYTHON}" ]; then
            echo "ERROR: Python executable not found in PATH (set PYTHON or VENV)" >&2
            exit 1
        fi
        ;;
esac
OUTPUT="${OUTPUT:-${REPO_ROOT}/Mu-r8q-0.img}"
case "${OUTPUT}" in
    /*) ;;
    *) OUTPUT="${PWD}/${OUTPUT}" ;;
esac
mkdir -p "$(dirname "${OUTPUT}")"
install -m 0644 "${DTB}" "${DTB_DEST}"
(
    cd "${MUSIL}"
    "${PYTHON}" build_uefi.py -d r8q
)
UEFI_IMAGE="${MUSIL}/Mu-r8q-0.img"
if [ ! -s "${UEFI_IMAGE}" ]; then
    echo "ERROR: Mu-Silicium build did not produce ${UEFI_IMAGE}" >&2
    exit 1
fi
if [ "${OUTPUT}" != "${UEFI_IMAGE}" ]; then
    cp "${UEFI_IMAGE}" "${OUTPUT}"
fi
echo "Mu-Silicium r8q firmware image: ${OUTPUT}"
