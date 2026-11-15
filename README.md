# Fedora development image

A Fedora 44 image for Microsandbox on amd64 and arm64.

Includes Codex, Claude Code, OpenCode, Pi, Go, PHP/Composer, Node.js/npm/pnpm,
Python/uv, Rust, Zig, Bun, Git/GitHub CLI, Podman, Kind, kubectl and OpenTofu (`tofu`).

## Build

Requires Podman and just. These commands build for the current host architecture
and use cached layers for fast local iteration.

```sh
just build
just shell
just msb-import
```

Run `just` to list commands. The default local image is
`localhost/dev-image:dev`.

Override the local tag as needed:

```sh
just tag=experiment build
```

Use the same user for all commands so they share container storage. Production
builds and multiarch publishing are handled by GitHub Actions.

## Run in Microsandbox

Import the archive on your Microsandbox host, then create a VM:

```sh
msb load --input fedora.oci.tar --tag localhost/msb-fedora:latest
msb create localhost/msb-fedora:latest --name fedora-dev --init auto --user dev
msb exec --user dev fedora-dev -- bash -l
```

The `dev` user has passwordless sudo. Keep `--init auto` to start systemd and
Podman. Existing VMs keep their filesystem when the image changes.

## Codex configuration

The image installs Codex and its shell completions. When launched through sbx,
Codex uses the shared configuration initialized by sbx at
`/home/dev/.codex/config.toml`. The initial template lives in sbx's
`config/codex.toml`; edit the shared file to change settings for your projects.

For direct Microsandbox use, configure Codex through `~/.codex/config.toml`, a
trusted project's `.codex/config.toml`, or command-line options:

```sh
codex --model gpt-6.1-sol -c model_reasoning_effort=high
codex --sandbox workspace-write --ask-for-approval on-request
```

See [Codex configuration](https://learn.chatgpt.com/docs/config-file/config-basic)
for the supported settings. The image includes no Codex configuration or
credentials. Authentication uses `codex login`.

## npm tools

npm, pnpm and the npm-installed agents live in `/home/dev/.local`, owned by
`dev`. Global npm installs use `~/.local` for the current user, so `dev` can
update the preinstalled tools without sudo, including through Codex's updater:

```sh
npm install -g @openai/codex@latest
```

Launchers in `/usr/local/bin` also make the tools available to direct VM commands
and root shells. `NPM_CONFIG_GLOBALCONFIG=/etc/npmrc` keeps the shared npm policy
active with the user prefix. The image pins npm 11.17 or newer for
[`min-release-age-exclude`](https://docs.npmjs.com/cli/v11/using-npm/config#min-release-age-exclude)
support.

The seven-day release delay still applies to other npm packages. Exceptions in
`config/npmrc` cover the preinstalled agents, npm, pnpm and their companion
packages (including platform binaries), so these can update immediately. Other
dependencies still follow the delay. npm lifecycle scripts remain disabled by
default; the image build explicitly enables them while installing pinned tools.
Existing VMs need recreation from the rebuilt image or a separate migration to
this layout.

## Containers

Podman is ready to use inside the VM:

```sh
podman run --rm quay.io/podman/hello:latest
kind create cluster --name dev --config /usr/local/share/dev-image/kind.yaml --wait 5m
```

Kind requires the supplied configuration. Kubernetes Service routing and DNS
currently fail on the tested Microsandbox kernel; a runtime kernel fix is needed.

Runtime settings are in `config/`. GitHub Actions builds both architectures and
publishes to GHCR; Renovate maintains dependency pins.

## Automatic updates

Pushes to `main` build amd64 and arm64 images and publish the multiarch image.
A weekly rebuild runs on Mondays at
04:23 UTC without cached layers. The image workflow can also be run manually;
only the default branch publishes images.

Renovate opens dependency update PRs, including GitHub Actions updates. PRs build
both architectures without publishing. Renovate enables GitHub-native auto-merge
on its PRs, so GitHub merges as soon as the required checks pass, without waiting
for another Renovate run. The normal push to `main` then builds and publishes the
updated image.
