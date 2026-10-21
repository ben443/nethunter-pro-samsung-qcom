#!/bin/sh
# Handling Kali's network repos in: ./scripts/rootfs-cleanup.sh

DEBIAN_SUITE=$1
SUITE=$2

# Add debian-security for stable releases; note that only the main component is supported
if [ "${DEBIAN_SUITE}" = "bullseye" ] || [ "${DEBIAN_SUITE}" = "bookworm" ] || [ "${DEBIAN_SUITE}" = "trixie" ]; then
    echo "deb http://security.debian.org/ ${DEBIAN_SUITE}-security main" >> /etc/apt/sources.list
fi

# Remove mobian.list as mobian keyring contains mobian sources file
rm -fv /etc/apt/sources.list.d/mobian.list

# SSL verification failed fix for mobian repository
sed -i 's|https|http|g' /etc/apt/sources.list.d/mobian.sources

# Set the proper suite in our sources file
sed -i "s/Suites: .*/Suites: ${SUITE}/" /etc/apt/sources.list.d/mobian.sources

# Kali does not carry meta-phosh; allow only its metapackages from Debian.
cat > /etc/apt/sources.list.d/debian-phosh.sources << EOF
Types: deb
URIs: https://deb.debian.org/debian
Suites: sid
Components: main
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF

cat > /etc/apt/preferences.d/20-debian-phosh << EOF
Package: src:meta-phosh
Pin: release o=Debian
Pin-Priority: 100

Package: *
Pin: release o=Debian
Pin-Priority: -1
EOF

# Prefer certain packages from Mobian, rather than Kali
cat > /etc/apt/preferences.d/10-mobian-priority << EOF
Package: u-boot-menu*
Pin: release o=Mobian
Pin-Priority: 700

Package: alsa-ucm-conf
Pin: release o=Mobian
Pin-Priority: 700

Package: libqrtr1
Pin: release o=Mobian
Pin-Priority: 700

Package: protection-domain-mapper
Pin: release o=Mobian
Pin-Priority: 700

Package: qrtr-tools
Pin: release o=Mobian
Pin-Priority: 700
EOF

# Prefer Kali packages by default
cat > /etc/apt/preferences.d/00-kali-priority << EOF
Package: *
Pin: release o=Kali
Pin-Priority: 600
EOF
