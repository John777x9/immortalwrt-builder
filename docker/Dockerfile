FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive
ARG UID=1000
ARG GID=1000

# Build dependencies for ImmortalWrt / OpenWrt buildroot
# Reference: https://openwrt.org/docs/guide-developer/toolchain/install-buildsystem
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        ccache \
        ecj \
        fastjar \
        file \
        g++ \
        gawk \
        gettext \
        git \
        java-propose-classpath \
        libelf-dev \
        libncurses-dev \
        libncursesw5-dev \
        libssl-dev \
        python3 \
        python3-distutils \
        python3-setuptools \
        python3-dev \
        rsync \
        subversion \
        swig \
        time \
        unzip \
        wget \
        xsltproc \
        zlib1g-dev \
        bzip2 \
        flex \
        bison \
        libpython3-dev \
        qemu-utils \
        sudo \
        ca-certificates \
        curl \
        libfuse-dev \
        libusb-1.0-0-dev \
        ocaml \
        ocaml-findlib \
        ocaml-nox \
        zstd \
        less \
        nano \
        vim-tiny \
    && rm -rf /var/lib/apt/lists/*

# Non-root build user (OpenWrt refuses to compile as root)
RUN groupadd -g ${GID} builder \
 && useradd -m -u ${UID} -g ${GID} -s /bin/bash builder \
 && echo "builder ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/builder

USER builder
WORKDIR /home/builder/source

# ccache cache lives outside source tree, mounted as volume
ENV CCACHE_DIR=/home/builder/.ccache
ENV PATH=/usr/lib/ccache:$PATH

CMD ["/bin/bash"]
