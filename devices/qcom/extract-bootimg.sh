#!/bin/sh

SCRIPT="$0"
DEVICE="$1"
IMAGE="$2"

[ "$IMAGE" ] || exit 1

CONFIG="$(dirname ${SCRIPT})/configs/${DEVICE}.toml"
if ! [ -f "${CONFIG}" ]; then
    echo "ERROR: No configuration for device type '${DEVICE}'!"
    exit 1
fi

# Extract all supported variants from config
VARIANTS="$(tomlq -r 'foreach .device[] as $dev (0;
    if $dev.variant then
        [$dev.model, $dev.variant] | join("-")
    else
        $dev.model
    end
)' ${CONFIG})"

for variant in ${VARIANTS}; do
    echo "Extracting boot image for variant ${variant}"
    if [ -f "${ROOTDIR}/bootimg-${variant}" ]; then
        if [ "${DEVICE}" = "r8q" ]; then
            if [ ! -s "${ROOTDIR}/bootimg-${variant}" ] ||
                ! mv "${ROOTDIR}/bootimg-${variant}" "${ARTIFACTDIR}/${IMAGE}.boot-${variant}.img"; then
                echo "ERROR: unable to extract a valid r8q boot image" >&2
                exit 1
            fi
        else
            mv "${ROOTDIR}/bootimg-${variant}" "${ARTIFACTDIR}/${IMAGE}.boot-${variant}.img"
        fi
    else
        if [ "${DEVICE}" = "r8q" ]; then
            echo "ERROR: boot image for r8q was not generated" >&2
            exit 1
        fi
        echo "WARN: boot image for variant ${variant} was not generated; skipping extraction"
    fi
done
