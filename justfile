tag := "dev"
image := "ghcr.io/kaplan-michael/dev-image:" + tag

# List available commands.
default:
    @just --list

# Build locally with cached layers.
build:
    #!/usr/bin/env bash
    mapfile -t image_env < <(sed '/^#/d; /^$/d; s/^/--env=/' config/environment.env)
    podman build --layers --tag {{quote(image)}} "${image_env[@]}" .

# Open an interactive shell as dev in the local image.
shell:
    podman run --rm --interactive --tty --user dev {{quote(image)}} bash -l

msb-import:
    #!/usr/bin/env bash
    set -euo pipefail
    podman save --format docker-archive {{quote(image)}} | microsandbox load
