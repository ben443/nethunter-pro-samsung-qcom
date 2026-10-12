#!/bin/sh

set -eu

RESUME_CONF="/etc/initramfs-tools/conf.d/resume"
BACKUP=""
HAD_RESUME=0
UPDATED=0

cleanup() {
    if [ "${HAD_RESUME}" -eq 1 ]; then
        mv "${BACKUP}" "${RESUME_CONF}"
    else
        rm -f "${RESUME_CONF}" "${BACKUP}"
    fi
}
trap cleanup EXIT

if [ -f "${RESUME_CONF}" ]; then
    BACKUP="$(mktemp)"
    cp "${RESUME_CONF}" "${BACKUP}"
    HAD_RESUME=1
fi

echo "RESUME=none" > "${RESUME_CONF}"

for kernel_image in /boot/vmlinuz-*; do
    [ -f "${kernel_image}" ] || continue
    version="${kernel_image#/boot/vmlinuz-}"
    case "${version}" in
        *.gz|*.xz|*.zst|*.lz4|*.bz2)
            version="${version%.*}"
            ;;
    esac
    [ -d "/lib/modules/${version}" ] || [ -d "/usr/lib/linux-image-${version}" ] || continue

    for module in ufs-qcom phy-qcom-qmp-ufs; do
        if ! modinfo -k "${version}" "${module}" >/dev/null 2>&1; then
            echo "ERROR: required r8q initramfs module ${module} is missing for ${version}" >&2
            exit 1
        fi
    done

    update-initramfs -u -k "${version}"
    initrd="/boot/initrd.img-${version}"
    if [ ! -s "${initrd}" ] || ! command -v lsinitramfs >/dev/null 2>&1; then
        echo "ERROR: unable to inspect generated r8q initramfs ${initrd}" >&2
        exit 1
    fi
    initrd_contents="$(lsinitramfs "${initrd}")"
    for module in ufs-qcom phy-qcom-qmp-ufs; do
        if ! printf '%s\n' "${initrd_contents}" | grep -Eq "/${module}[.]ko([.][[:alnum:]]+)?$"; then
            echo "ERROR: generated r8q initramfs is missing required module ${module}" >&2
            exit 1
        fi
    done
    UPDATED=1
done

if [ "${UPDATED}" -eq 0 ]; then
    echo "ERROR: no installed r8q kernel artifacts found for initramfs update" >&2
    exit 1
fi
