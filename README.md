# Fedora development image

A Fedora 44 image for Microsandbox on amd64 and arm64.

Includes Codex, Claude Code, OpenCode, Pi, Go, PHP/Composer, Node.js/npm/pnpm,
Python/uv, Rust, Zig, Bun, Git/GitHub CLI, Podman, Kind, kubectl, Kustomize and
OpenTofu (`tofu`).

## Build

Requires Podman and just. These commands build for the current host architecture
and use cached layers for fast local iteration.

```sh
just build
just shell
just msb-import
```

Run `just` to list commands. The default local image is
`ghcr.io/kaplan-michael/dev-image:dev`.

Override the local tag as needed:

```sh
just tag=experiment build
```

Use the same user for all commands so they share container storage. Production
builds and multiarch publishing are handled by GitHub Actions.

## Containers

Podman is ready to use inside the VM:

```sh
podman run --rm quay.io/podman/hello:latest
kind create cluster --name dev --wait 5m
```

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
