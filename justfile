set default-list

image := "localhost/msb-fedora:latest"

# Build for the host's native architecture.
build:
    #!/usr/bin/env bash
    set -euo pipefail
    image_env=()
    while IFS= read -r setting; do
        case $setting in ''|\#*) continue ;; esac
        image_env+=(--env "$setting")
    done < config/environment.env
    podman build --layers "${image_env[@]}" --tag {{quote(image)}} --file Containerfile .

# Check agents, shell modes, environment and lazy-loaded completions.
test:
    #!/usr/bin/env bash
    set -euo pipefail
    podman run --rm --user dev {{quote(image)}} bash -lc 'id && codex --version && claude --version && opencode --version && pi --version && bun --version && kind version'
    for user in dev root; do
        podman run --rm --user "$user" {{quote(image)}} bash -ec '
            while IFS="=" read -r name value; do
                case $name in ""|\#*) continue ;; esac
                [[ ${!name} == "$value" ]]
            done < /etc/dev-environment.env
        '
        podman run --rm --user "$user" {{quote(image)}} env \
            -u CONTAINER_HOST -u DOCKER_HOST -u KIND_EXPERIMENTAL_PROVIDER \
            -u KIND_EXPERIMENTAL_CONTAINERD_SNAPSHOTTER -u COMPOSER_HOME \
            -u COMPOSER_SKIP_SCRIPTS -u LANG -u EDITOR bash -elc '
                set -e
                [[ $(stat -c %a /etc/profile.d/00-dev-environment.sh) == 644 ]]
                [[ $CONTAINER_HOST == unix:///run/podman/podman.sock ]]
                [[ $DOCKER_HOST == unix:///run/podman/podman.sock ]]
                [[ $KIND_EXPERIMENTAL_PROVIDER == podman ]]
                [[ $KIND_EXPERIMENTAL_CONTAINERD_SNAPSHOTTER == fuse-overlayfs ]]
                [[ $COMPOSER_HOME == /etc/composer && $EDITOR == vi && $LANG == C.UTF-8 ]]
                [[ -n $COMPOSER_SKIP_SCRIPTS ]]
                [[ $(stat -c %a /etc/sysctl.d/90-microsandbox-pid-max.conf) == 644 ]]
                grep -qx "kernel.pid_max = 4096" /etc/sysctl.d/90-microsandbox-pid-max.conf
                test -r /usr/local/share/dev-image/kind.yaml
                systemctl is-enabled chronyd.service
            '
        for mode in -c -lc -ic -lic; do
            podman run --rm --tty --env TERM=dumb --user "$user" {{quote(image)}} bash -e "$mode" '
                set -e
                for tool in codex claude opencode pi kind kubectl podman docker buildah skopeo \
                    node npm pnpm bun go cargo rustc python3 uv php composer zig git gh sudo; do
                    command -v "$tool" >/dev/null
                done
                [[ $CONTAINER_HOST == unix:///run/podman/podman.sock ]]
                [[ $DOCKER_HOST == unix:///run/podman/podman.sock ]]
                [[ $KIND_EXPERIMENTAL_PROVIDER == podman ]]
                [[ $KIND_EXPERIMENTAL_CONTAINERD_SNAPSHOTTER == fuse-overlayfs ]]
                IFS=: read -ra directories <<< "$PATH"
                seen_paths=:
                for directory in "${directories[@]}"; do
                    [[ -n $directory && $seen_paths != *":$directory:"* ]]
                    seen_paths+="$directory:"
                done
                if [[ $- == *i* ]] || shopt -q login_shell; then
                    command -v ip >/dev/null
                    for directory in "$HOME/.local/bin" "$HOME/bin" "$HOME/.bun/bin" \
                        "$HOME/.cargo/bin" "$HOME/go/bin" /usr/local/sbin /usr/sbin \
                        "$COMPOSER_HOME/vendor/bin"; do
                        [[ :$PATH: == *":$directory:"* ]]
                    done
                fi
                if [[ $- == *i* ]]; then
                    export EXPECTED_PATH=$PATH
                    bash -ic '\''[[ $PATH == "$EXPECTED_PATH" ]]'\''
                    bash -lic '\''[[ $PATH == "$EXPECTED_PATH" ]]'\''
                    for tool in codex podman kind kubectl git gh; do
                        if ! complete -p "$tool" >/dev/null 2>&1; then
                            _comp_load "$tool"
                        fi
                        complete -p "$tool" >/dev/null
                    done
                    HISTFILE=$(mktemp)
                    history -s shell-history-ok
                    for prompt_hook in "${PROMPT_COMMAND[@]}"; do
                        eval "$prompt_hook"
                    done
                    history -c
                    history -r
                    [[ $(history 1) == *shell-history-ok ]]
                    expected_prompt=$(declare -p PROMPT_COMMAND)
                    expected_completions=$(complete -p codex podman kind kubectl)
                    . /etc/profile.d/00-dev-environment.sh
                    [[ $PATH == "$EXPECTED_PATH" ]]
                    [[ $(declare -p PROMPT_COMMAND) == "$expected_prompt" ]]
                    [[ $(complete -p codex podman kind kubectl) == "$expected_completions" ]]
                fi
                printf "PASS %s %s PATH=%s\n" "$(id -un)" "$-" "$PATH"
            '
        done
    done

# Export for import on the Microsandbox host.
save archive="fedora.oci.tar":
    podman save --format oci-archive --output {{quote(archive)}} {{quote(image)}}

msb-import:
    podman save --format docker-archive {{quote(image)}} | microsandbox load
