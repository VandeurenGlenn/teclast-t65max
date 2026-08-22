FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        bc bison build-essential ccache curl file flex g++-multilib \
        gcc-multilib git git-lfs gnupg gperf imagemagick \
        lib32readline-dev lib32z1-dev libelf-dev liblz4-tool libssl-dev \
        libxml2-utils lzop openjdk-17-jdk-headless pngcrush \
        protobuf-compiler python3 python-is-python3 rsync schedtool \
        squashfs-tools unzip xsltproc xz-utils zip zlib1g-dev \
    && curl -fsSL https://storage.googleapis.com/git-repo-downloads/repo \
        -o /usr/local/bin/repo \
    && chmod 0755 /usr/local/bin/repo \
    && git lfs install --system \
    && rm -rf /var/lib/apt/lists/*

ENV USE_CCACHE=1 \
    CCACHE_DIR=/src/.ccache \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

WORKDIR /src
CMD ["bash"]
