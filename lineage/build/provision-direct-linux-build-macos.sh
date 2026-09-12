#!/bin/sh
set -eu

EXTERNAL_VOLUME=${T65MAX_BUILD_VOLUME:-/Volumes/LineageBuild}
PROFILE=${COLIMA_PROFILE:-lineage-linux}
export COLIMA_HOME=${T65MAX_COLIMA_HOME:-$EXTERNAL_VOLUME/t65max/colima-linux-home}
SSH_CONFIG="$COLIMA_HOME/ssh_config"
VM_HOST="colima-$PROFILE"

# Package installation is the only privileged part. Android itself is built by
# the ordinary Lima user on the VM-native ext4 filesystem.
ssh -t -F "$SSH_CONFIG" "$VM_HOST" '
    sudo dpkg --add-architecture amd64
    if ! grep -q "^Architectures:" /etc/apt/sources.list.d/ubuntu.sources; then
        sudo sed -i "/^Types: deb$/a Architectures: arm64" /etc/apt/sources.list.d/ubuntu.sources
    fi
    printf "%s\n" \
        "Types: deb" \
        "URIs: http://archive.ubuntu.com/ubuntu" \
        "Suites: noble noble-updates noble-backports" \
        "Components: main universe restricted multiverse" \
        "Architectures: amd64" \
        "Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg" \
        "" \
        "Types: deb" \
        "URIs: http://security.ubuntu.com/ubuntu" \
        "Suites: noble-security" \
        "Components: main universe restricted multiverse" \
        "Architectures: amd64" \
        "Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg" \
        | sudo tee /etc/apt/sources.list.d/ubuntu-amd64.sources >/dev/null
    sudo apt-get update
    sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        bc bison build-essential ccache curl file flex git git-lfs gnupg gperf \
        imagemagick libelf-dev liblz4-tool libssl-dev libxml2-utils lzop \
        openjdk-17-jdk-headless pngcrush protobuf-compiler python-is-python3 \
        rsync schedtool squashfs-tools unzip xsltproc xz-utils zip zlib1g-dev \
        libc6:amd64 libgcc-s1:amd64 libstdc++6:amd64 zlib1g:amd64 \
        libncurses6:amd64 libtinfo6:amd64
    sudo apt-get clean
'

ssh -F "$SSH_CONFIG" "$VM_HOST" 'test -x /lib64/ld-linux-x86-64.so.2 && command -v ccache >/dev/null && command -v java >/dev/null'
echo "Direct Linux build environment is ready."
