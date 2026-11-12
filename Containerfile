FROM registry.fedoraproject.org/fedora:44@sha256:102f5031dc46ed1975bd2cd98bdf19c59617f3f0026310022f3cb680abe056d3

# Fedora development userspace for a Microsandbox Linux VM.
# Microsandbox provides the guest kernel and optional PID 1 handoff.
RUN dnf upgrade --refresh -y \
    && dnf install -y \
        bash bash-completion sudo shadow-utils passwd ca-certificates curl wget \
        systemd systemd-pam dbus-broker chrony \
        golang \
        php-cli php-common php-mbstring php-xml php-intl php-pdo \
        php-mysqlnd php-pgsql php-gd php-process php-opcache php-pecl-zip composer \
        nodejs24 nodejs24-npm python3 uv rust cargo zig \
        git gh ripgrep fd-find jq vim-minimal nano less \
        tar gzip bzip2 xz unzip zip which findutils diffutils patch \
        gcc gcc-c++ make cmake pkgconf-pkg-config autoconf automake libtool \
        podman podman-docker buildah skopeo crun netavark aardvark-dns fuse-overlayfs kubernetes-client \
        iproute iputils bind-utils nftables iptables-nft procps-ng util-linux \
        openssh-clients sox alsa-utils bubblewrap \
    && dnf clean all

# Development user with passwordless sudo INSIDE the VM.
# Keep OCI default user as root for system initialization.
RUN groupadd -g 1000 dev \
    && useradd -m -u 1000 -g dev -s /bin/bash dev \
    && groupadd --system podman \
    && usermod -aG podman dev \
    && printf 'dev ALL=(ALL) NOPASSWD:ALL\n' > /etc/sudoers.d/dev \
    && chmod 0440 /etc/sudoers.d/dev

# Native package-manager defaults, retained from the existing image.
COPY config/npmrc /etc/npmrc
COPY config/bunfig.toml /etc/skel/.bunfig.toml
COPY --chown=dev:dev config/bunfig.toml /home/dev/.bunfig.toml
COPY config/composer.json /etc/composer/config.json

# Version pins, verified downloads, agent installation and completion generation.
COPY config/tools.env /usr/local/share/dev-image/tools.env
COPY scripts/install-tools.sh /tmp/install-tools.sh
RUN bash /tmp/install-tools.sh && rm /tmp/install-tools.sh

# Runtime configuration follows tool installation to preserve the build cache.
# Podman storage on Microsandbox's layered filesystem.
# Keep the working FUSE setup without allocating a separate disk.
COPY config/storage.conf /etc/containers/storage.conf
COPY config/containers.conf /etc/containers/containers.conf
COPY --chmod=0644 config/10-podman-socket.conf /etc/systemd/system/podman.socket.d/10-podman-socket.conf
RUN systemctl enable podman.socket chronyd.service

# Fedora's stock user dotfiles load this for login and interactive Bash.
COPY --chmod=0644 config/environment.env /etc/dev-environment.env
COPY --chmod=0644 config/dev-environment.sh /etc/profile.d/00-dev-environment.sh

# Match the supported PID limit of the current Microsandbox kernel at boot.
COPY --chmod=0644 config/90-microsandbox-pid-max.conf /etc/sysctl.d/90-microsandbox-pid-max.conf
COPY --chmod=0644 config/kind.yaml /usr/local/share/dev-image/kind.yaml

WORKDIR /workspace
CMD ["/bin/bash"]
