FROM registry.fedoraproject.org/fedora:44

# Clawk creates the agent user with the host UID/GID and grants sudo at boot.
# This image supplies the filesystem and tools; clawk-init supplies PID 1.
RUN dnf install -y \
        bash sudo shadow-utils passwd ca-certificates curl wget \
        golang \
        php-cli php-common php-mbstring php-xml php-intl php-pdo \
        php-mysqlnd php-pgsql php-gd php-process php-opcache php-pecl-zip composer \
        nodejs24 nodejs24-npm python3 uv rust cargo zig \
        git gh ripgrep fd-find jq vim-minimal nano less \
        tar gzip bzip2 xz unzip zip which findutils diffutils patch \
        gcc gcc-c++ make cmake pkgconf-pkg-config autoconf automake libtool \
        podman buildah skopeo crun netavark aardvark-dns fuse-overlayfs \
        iproute iputils bind-utils nftables iptables-nft procps-ng util-linux \
        openssh-clients sox alsa-utils \
    && dnf clean all

ARG BUN_VERSION=1.4.2
ARG KIND_VERSION=0.33.0
RUN set -eu; \
    dnf install -y kubernetes-client; \
    dnf clean all; \
    case "$(uname -m)" in \
        x86_64) \
            arch=amd64; bun_arch=x64-baseline; \
            bun_sha=c678040f14fe0440eb839d37cbd0ce4c051a32da72806ac97de6a6aab6bf728f; \
            kind_sha=aee6151561422756b764a4ae28e7f44cda5af5a9eead3cc9985112b1de8d8e0d ;; \
        aarch64) \
            arch=arm64; bun_arch=aarch64; \
            bun_sha=54328bbc2d9c8e0c9f892c544d66c57a83b84139e34909e5ee81758f1ac8fda7; \
            kind_sha=20022bee6cfcd5086cb7234d218e3454e6090022f2a8f55d1fa7fcf42c3867a2 ;; \
        *) echo 'Supported architectures: amd64 and arm64' >&2; exit 1 ;; \
    esac; \
    curl --fail --location --retry 3 \
        "https://github.com/oven-sh/bun/releases/download/bun-v${BUN_VERSION}/bun-linux-${bun_arch}.zip" \
        -o /tmp/bun.zip; \
    printf '%s  %s\n' "$bun_sha" /tmp/bun.zip | sha256sum -c -; \
    unzip -q /tmp/bun.zip -d /tmp/bun; \
    install -m 755 "/tmp/bun/bun-linux-${bun_arch}/bun" /usr/local/bin/bun; \
    curl --fail --location --retry 3 \
        "https://github.com/kubernetes-sigs/kind/releases/download/v${KIND_VERSION}/kind-linux-${arch}" \
        -o /tmp/kind; \
    printf '%s  %s\n' "$kind_sha" /tmp/kind | sha256sum -c -; \
    install -m 755 /tmp/kind /usr/local/bin/kind; \
    rm -r /tmp/bun /tmp/bun.zip /tmp/kind

ENV PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin \
    NPM_CONFIG_GLOBALCONFIG=/etc/npmrc \
    KIND_EXPERIMENTAL_PROVIDER=podman \
    COMPOSER_HOME=/etc/composer \
    COMPOSER_SKIP_SCRIPTS=pre-install-cmd,post-install-cmd,pre-update-cmd,post-update-cmd,pre-autoload-dump,post-autoload-dump,post-root-package-install,post-create-project-cmd \
    LANG=C.UTF-8

COPY config/npmrc /etc/npmrc
COPY config/bunfig.toml /etc/skel/.bunfig.toml
COPY config/bunfig.toml /root/.bunfig.toml
COPY config/composer.json /etc/composer/config.json
COPY config/containers.conf /etc/containers/containers.conf.d/90-clawk.conf

# Install system-wide CLIs through npm so it manages their command links.
# These build-time installs need scripts to set up their native binaries.
# Allow these pinned tools to be newer than the normal seven-day age window.
ARG CLAUDE_CODE_VERSION=2.1.300
ARG CODEX_VERSION=0.163.0
ARG PI_VERSION=1.2.0
ARG OPENCODE_VERSION=1.19.0
ARG PNPM_VERSION=12.11.2
RUN set -eu; \
    npm install --global --ignore-scripts=false --min-release-age=0 --no-audit \
        "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" \
        "@openai/codex@${CODEX_VERSION}" \
        "@earendil-works/pi-coding-agent@${PI_VERSION}" \
        "opencode-ai@${OPENCODE_VERSION}" \
        "pnpm@${PNPM_VERSION}"; \
    claude --version; \
    codex --version; \
    pi --version; \
    opencode --version; \
    pnpm --version; \
    npm cache clean --force

# Composer otherwise tries to create this file even when reading global config.
RUN printf '{}\n' > /etc/composer/auth.json

WORKDIR /workspace
CMD ["/bin/bash"]
