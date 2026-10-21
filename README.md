# Fedora runner for Clawk

`Containerfile` builds a Fedora 44 image for amd64 or arm64 with Go;
PHP CLI/extensions and Composer; Node/npm/pnpm; Python/uv; Rust/Cargo;
Bun; Zig; Git, gh, jq, ripgrep and fd; editors, archive and native build tools;
Claude, Codex, pi and OpenCode; and Podman, Buildah, Skopeo, Kind and kubectl.
The npm CLIs are installed globally under `/usr/local`, with versions pinned
in `Containerfile` and command links managed by npm. Their transitive
dependencies are resolved at build time. Bun and Kind downloads are pinned
and checksum-verified; kubectl is installed from Fedora's
`kubernetes-client` package.

On macOS, Clawk creates the agent user with the host UID/GID and grants sudo;
the experimental Linux provider currently runs sessions as root. The image
uses no fixed UID, HOME, SSH server or systemd boot. System dependencies are
baked into the image; use Clawk's `on up` for per-boot workspace preparation
on macOS. Linux's provider does not currently run those hooks.

## Suitability and verification

This is a good fit for a Clawk sandbox that needs several language toolchains,
PHP, and container/Kubernetes tools. Its filesystem and environment follow
[Clawk v0.4.0's image contract](https://github.com/clawkwork/clawk/blob/v0.4.0/docs/images.md):
Clawk injects its own init and agent, and imports the image's environment.
The image's `CMD` is only useful when running it directly with Docker/Podman.

Previous image build, checked on 2026-10-14:

- The amd64 Podman build completed using the existing build cache. The image
  is approximately **5.01 GB uncompressed**; the archive and Clawk disk/cache
  require additional host storage.
- Version checks passed for the language tools, package managers, all four
  agents, and Podman/Buildah/Skopeo/Kind/kubectl. Claude, Codex, pi, OpenCode,
  pnpm, Go, Rust and Zig also ran as an arbitrary non-root user.
- npm's script/age defaults, Composer's plugin/cooldown settings, the home
  copy of Bun's configuration, and PHP extensions were checked.
- Bun and Kind hashes for both architectures match the published release
  asset digests. The arm64 image has not been built or run in this review.
- A Clawk VM boot and an in-guest Podman/Kind workload have **not** been
  tested here: this environment has no Clawk binary or `/dev/kvm`.

This is a large toolbox rather than a minimal image. The tested versions
include PHP 8.5.11, Node 24.18.0, Python 3.14.7 and Zig 0.16.0; check your
project's version constraints. Fedora packages and the base tag can change
between builds. The CLI version pins and binary hashes pin part of the toolchain;
keeping a built archive fixes the actual image used by Clawk.

## Build wrapper with just

Requires [just](https://just.systems/) 1.23+, Bash, and a running Docker or
Podman engine. From this repository:

```sh
just          # list commands
just build    # build, export, and print the Clawk config
just image    # build only
just save     # export an existing image
just config   # print the Clawk config
just info     # show resolved settings
```

Edit `.env` beside the build files; copy `.env.example` if needed. Shell
variables override `.env`. For a separate environment file, use
`just --dotenv-path .env.mac build`.

| Variable | Default / purpose |
| --- | --- |
| `CLAWK_ENGINE` | `podman`; also supports `docker` or a path to either executable |
| `CLAWK_IMAGE_TAG` | `localhost/clawk-fedora:44` |
| `CLAWK_IMAGE_DIR` | `$XDG_DATA_HOME/clawk/images` or `~/.local/share/clawk/images` |
| `CLAWK_IMAGE_ARCHIVE` | Full filename; defaults to `CLAWK_IMAGE_DIR/clawk-fedora-44.tar` |

For example:

```sh
CLAWK_ENGINE=docker CLAWK_IMAGE_DIR="$HOME/VM Images/clawk" just build
```

Builds always use this repository's `Containerfile` and root directory;
unchanged layers can use the engine's cache. Both build and export run as
your current user. The export creates its destination directory and replaces
an existing archive only after saving succeeds.

`just config` prints an absolute image path. Merge the printed setting into
project `clawk.mod` or `~/.config/clawk/clawk.mod`; Clawk does not automatically
scan the export directory. Relative path overrides resolve against this
repository, and `.env*` files are excluded from the build context and Git.
Run from elsewhere with `just --justfile /path/to/agent-images/justfile`.

## Manual build and use

```sh
cd /path/to/agent-images
podman build -t localhost/clawk-fedora:44 -f Containerfile .
podman save --format docker-archive -o clawk-fedora.tar localhost/clawk-fedora:44
```

Build for the Clawk host's native architecture: arm64 on Apple silicon,
amd64 on an x86-64 Linux host, or arm64 on an arm64 Linux host. Docker/Podman
on Apple silicon builds through an arm64 Linux VM. Start your container
engine before building; for a new Podman installation on macOS, run
`podman machine init` and `podman machine start` first.

If rootless Podman on Linux reports insufficient UIDs/GIDs or missing
`/etc/subuid`/`/etc/subgid` ranges, configure subordinate IDs for your user
as part of the host's rootless Podman setup. Use the same engine connection
and user for build and export so both commands see the same image store.

Docker is an alternative:

```sh
docker build -t clawk-fedora:44 -f Containerfile .
docker save -o clawk-fedora.tar clawk-fedora:44
```

Use `save`, which preserves image layers and environment metadata. Clawk
reads a Docker-format archive, not the image in your local container engine's
store, so the archive path is the straightforward local-image option.

Install Clawk on the host. On Apple silicon with macOS 14 or newer:

```sh
brew install clawkwork/tap/clawk
clawk doctor
```

On Linux, follow
[Clawk's Linux quick start](https://github.com/clawkwork/clawk/blob/v0.4.0/docs/linux-quickstart.md):
install its release binary, Firecracker and `util-linux`, ensure your user can
read/write `/dev/kvm`, then run `clawk doctor`. Docker/Podman builds the image;
it does not replace the host hypervisor requirements.

Copy the archive to the host where Clawk runs if you built it elsewhere.
In the **project you want to work on**, add this to `clawk.mod`, using the
archive's absolute path on that host:

```text
sandbox (
    vm (
        image "/absolute/path/clawk-fedora.tar"
        cpu 4
        memory 4GiB
        memory_max 8GiB
        disk 64GiB
    )
)
```

Choose resources that fit your host. For Kind, start with capacity for at
least 8 GiB of guest RAM and 64 GiB of disk. Clawk can reject a VM whose memory
ceiling would exceed the host's available budget. Omit `memory_max` or lower
it for a smaller host when running ordinary development workloads.

For a personal default across projects, put an anonymous `sandbox ( ... )`
block in `~/.config/clawk/clawk.mod` instead. Project settings override it.
See [configuration](https://github.com/clawkwork/clawk/blob/v0.4.0/docs/configuration.md).

Start in a project directory that does not already have a Clawk sandbox:

```sh
cd /path/to/your-project
clawk run shell
```

On Linux, use `clawk --provider firecracker run shell`. For image selection
without a configuration file, use
`clawk --image /absolute/path/clawk-fedora.tar run shell` (also add the
provider flag on Linux).

Inside the guest, check the toolchain before starting an agent:

```sh
id
go version
php -v
node --version
python3 --version
claude --version
codex --version
pi --version
opencode --version
```

Exit the shell, then start the desired runner from the host:

```sh
clawk run claude
clawk run codex
clawk run pi
clawk run opencode
```

Choose one runner command; each starts its own session. For Claude, authenticate
once on the host with `claude setup-token`, `clawk auth set-token`, and
`clawk auth status`. Other runners use their own login/setup flow.

Clawk snapshots configuration when it creates a sandbox. Editing `clawk.mod`
does not switch an existing sandbox's image or resources. Use a fresh sandbox
to try a changed configuration, and preserve any guest-only work before
recreating an existing one.

## Podman and Kind inside the guest

Podman runs rootlessly as Clawk's `agent` user. Check image extraction and
container startup before trying Kubernetes:

```sh
podman info
podman run --rm registry.fedoraproject.org/fedora:latest echo hello
podman run --rm --user 12345:12345 registry.fedoraproject.org/fedora:latest id
```

Rootless operation relies on Clawk's guest initialization for subordinate
UID/GID ranges, mapping-helper privileges, device access, and cgroup delegation.
This image supplies the container tools and their default configuration.

Keep Kind rootful; it also needs sufficient guest resources and cgroup access:

```sh
sudo env KIND_EXPERIMENTAL_PROVIDER=podman kind create cluster \
  --name clawk --wait 5m --kubeconfig /root/.kube/clawk-kind
sudo kubectl --kubeconfig /root/.kube/clawk-kind get nodes
sudo env KIND_EXPERIMENTAL_PROVIDER=podman kind delete cluster --name clawk
```

Keep the same privilege level when managing containers or the cluster; rootful
and rootless Podman have separate image stores. Podman is configured
for cgroupfs and file logging/events, so it does not require a systemd service
in the guest. Rootless Kind relies on Clawk's cgroup delegation and Podman
configuration; it has not been verified here.

Ordinary Podman containers and Kind do **not** require nested virtualization
or guest `/dev/kvm`. They do need a compatible guest kernel with namespaces,
cgroups, overlayfs and bridge/netfilter support. Installing these tools in
the image cannot supply missing kernel features. If the small container
fails, diagnose that before trying Kind; an alternate guest kernel may be
needed, especially with Linux's minimal Firecracker CI kernel.

Clawk filters egress on the host. Common registries are allowed by default,
but redirects, private registries and Fedora mirrors may need additional
grants. On the host, find the sandbox name and inspect denials:

```sh
clawk list
clawk network denials SANDBOX_NAME
clawk network allow SANDBOX_NAME required-host.example
```

Replace the placeholders with your sandbox and the required destination.
Keep host shares and credential forwarding explicit. `agent-runner` is
independent.

## Persistence and provider limits

On macOS, the project and supported agent-state directories are mounted from
the host. The VM root filesystem is rebuilt on a cold boot: system packages
installed interactively, container images, Kind clusters and files elsewhere
in the guest disappear. Bake system changes into this image, and use
idempotent `on up` hooks for services that must start each boot.

On Linux with Clawk v0.4.0, the project is **copied into the VM**. Guest edits
do not sync back to your host. `clawk down` followed by `clawk up` discards
guest changes and agent history; `clawk snapshot` followed by `clawk resume`
preserves the VM. Copy or push results out before a cold restart or destroy.
Linux also lacks host-file push, SSH-agent forwarding and per-boot hooks.
See [the Linux provider's limits](https://github.com/clawkwork/clawk/blob/v0.4.0/docs/linux-quickstart.md#5-limits).

For a web service, add `forwards ( 3000 )` to the sandbox configuration before
creation and bind the guest server to `0.0.0.0:3000`; then open
`http://localhost:3000` on the host.

## Installation defaults

Native configuration lives in `config/`: npm uses `/etc/npmrc`, Bun's
`.bunfig.toml` is seeded into the agent home and root home, Composer reads
`/etc/composer/config.json`, and Podman uses its system configuration directory.
npm and Bun skip installation scripts and prefer packages at least seven days
old. Composer disallows plugins and uses a seven-day cooldown;
`COMPOSER_SKIP_SCRIPTS` skips its installation/update lifecycle hooks.
The image build enables npm scripts and disables the npm age window for the
global CLI install, including its dependencies, so the pinned releases can be
installed and set up their native binaries. It then checks that each CLI starts.
These command-line overrides apply only to that build step.
Agents retain sudo and can override these defaults:

```sh
npm install --ignore-scripts=false
COMPOSER_SKIP_SCRIPTS= composer install
```

For Bun, set `ignoreScripts = false` in the project's `[install]` section to
enable scripts, and `minimumReleaseAge = 0` to relax the age preference. Composer plugins need the
project's `allow-plugins` permission. Explicit custom Composer commands such as
`composer run test` remain available. These settings use the managers' native
[Bun configuration](https://bun.com/docs/runtime/bunfig),
[Composer configuration](https://getcomposer.org/doc/06-config.md), and
[Composer environment variables](https://getcomposer.org/doc/03-cli.md#composer-skip-scripts).

## KVM idea for later

Rebuild [Clawk's Kata-based kernel recipe](https://github.com/clawkwork/clawk/tree/a67d04f102152a67df4228d52da9812aa82ffe50/images/guest-kernel),
preserving its virtio, vsock, 9p and sound support, with built-in KVM and the
container/cgroup/networking options. Host virtualization support and a provider
that exposes nesting are also required. Reviewed Clawk v0.4.0 has no QEMU
provider and rejects nesting with Firecracker. No kernel build is included here.
