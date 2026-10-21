set dotenv-load
set default-list

# Settings from .env or the shell.
export engine := env('CLAWK_ENGINE', 'podman')
export image_tag := env('CLAWK_IMAGE_TAG', 'localhost/clawk-fedora:44')

xdg_data := env('XDG_DATA_HOME', '')
data_dir := if xdg_data =~ '^/' { xdg_data } else { home_directory() / '.local/share' }
image_dir := env('CLAWK_IMAGE_DIR', data_dir / 'clawk/images')
export archive := absolute_path(env('CLAWK_IMAGE_ARCHIVE', image_dir / 'clawk-fedora-44.tar'))

# Build, export, and print the Clawk config.
build: image save config

# Build the image from this repository.
image:
    @"$engine" build --tag "$image_tag" --file Containerfile .

# Export the image; replace the archive only on success.
save:
    #!/usr/bin/env bash
    set -eu
    if [[ -d "$archive" ]]; then
        printf 'Archive destination is a directory: %s\n' "$archive" >&2
        exit 2
    fi
    directory=$(dirname "$archive")
    mkdir -p "$directory"
    temporary=$(mktemp "$directory/.clawk-image.XXXXXXXX")
    trap 'rm -f "$temporary"' EXIT
    case "${engine##*/}" in
        podman) "$engine" save --format docker-archive --output "$temporary" "$image_tag" ;;
        docker) "$engine" save --output "$temporary" "$image_tag" ;;
        *) printf 'Unsupported engine: %s\n' "$engine" >&2; exit 2 ;;
    esac
    mv -f "$temporary" "$archive"
    printf 'Saved image: %s\n' "$archive" >&2

# Print the sandbox block for clawk.mod.
config:
    #!/usr/bin/env bash
    set -eu
    path=${archive//\\/\\\\}
    path=${path//\"/\\\"}
    path=${path//$'\n'/\\n}
    path=${path//$'\r'/\\r}
    path=${path//$'\t'/\\t}
    printf 'sandbox (\n    vm (\n        image "%s"\n    )\n)\n' "$path"

# Show the engine, image tag, and archive path.
info:
    @printf 'Engine: %s\nImage: %s\nArchive: %s\n' "$engine" "$image_tag" "$archive"
