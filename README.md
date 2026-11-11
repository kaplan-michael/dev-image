# Fedora development image

A Fedora 44 image for Microsandbox on amd64 and arm64.

Includes Codex, Claude Code, OpenCode, Pi, Go, PHP/Composer, Node.js/npm/pnpm,
Python/uv, Rust, Zig, Bun, Git/GitHub CLI, Podman, Kind and kubectl.

## Build

Requires Podman and just.

```sh
just build
just test
just save
just msb-import
```

Run `just` to list all commands. The default image is `localhost/msb-fedora:latest`.

## Run in Microsandbox

Import the archive on your Microsandbox host, then create a VM:

```sh
msb load --input fedora.oci.tar --tag localhost/msb-fedora:latest
msb create localhost/msb-fedora:latest --name fedora-dev --init auto --user dev
msb exec --user dev fedora-dev -- bash -l
```

The `dev` user has passwordless sudo. Keep `--init auto` to start systemd and
Podman. Existing VMs keep their filesystem when the image changes.

## Codex defaults

Codex starts with YOLO permissions (no command approvals or Codex sandbox),
`gpt-6.1-sol` and `medium` reasoning. Microsandbox provides VM isolation.

Edit `config/codex.toml` to change the image defaults, installed at
`/etc/codex/config.toml` for all users. Override them per user in
`~/.codex/config.toml`, per trusted project in `.codex/config.toml`, or per run:

```sh
codex --model gpt-6.1-sol -c model_reasoning_effort=high
codex --sandbox workspace-write --ask-for-approval on-request
```

These are [Codex configuration defaults](https://learn.chatgpt.com/docs/config-file/config-basic),
so higher-priority configuration can override them. Authentication still uses
`codex login`; no credentials are included in the image. Existing VMs need the
file copied into `/etc/codex/config.toml` or a new VM from the rebuilt image.

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

Pushes to `main` build amd64 and arm64 images and publish the multiarch
`ghcr.io/<owner>/<repository>:latest` image. A weekly rebuild runs on Mondays at
04:23 UTC without cached layers. The image workflow can also be run manually;
only the default branch publishes images.

Install the hosted [Renovate GitHub App](https://github.com/apps/renovate) for this
repository after pushing `renovate.json` to `main`, and complete onboarding if
prompted. The app manages its own credentials, schedule and Renovate version;
no Renovate Actions workflow, PAT or custom secret is needed.

Renovate opens dependency update PRs, including GitHub Actions updates. PRs build
both architectures without publishing. Renovate enables GitHub-native auto-merge
on its PRs, so GitHub merges as soon as the required checks pass, without waiting
for another Renovate run. The normal push to `main` then builds and publishes the
updated image. There is no hourly PR creation limit; the default limit of 10 open
PRs still applies. Major dependency upgrades remain disabled, and Fedora stays on 44.

Before enabling this configuration on `main`, set branch protection or a ruleset
to require `Build (amd64)` and `Build (arm64)` before merging. Enable **Require
branches to be up to date before merging** to test updates against the latest
`main`. Branch rules must permit Renovate to merge without a human review.
Then enable **Settings → General → Pull Requests → Allow auto-merge**.
GitHub-native auto-merge relies on these rules to wait for CI; without required
checks it can merge before builds finish. See [Renovate's platform automerge
requirements](https://docs.renovatebot.com/configuration-options/#platformautomerge).
Actions still uses `GITHUB_TOKEN` to publish to GHCR; allow package publication
in the repository settings.
