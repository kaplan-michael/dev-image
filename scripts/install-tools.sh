#!/usr/bin/env bash
# Build-time installation only; runtime shell setup lives in the profile drop-in.
set -euo pipefail
source /usr/local/share/dev-image/tools.env

case "$(uname -m)" in
    x86_64)
        arch=amd64; bun_arch=x64-baseline
        bun_tag=$BUN_AMD64_VERSION; bun_sha=$BUN_AMD64_SHA256
        kind_tag=$KIND_AMD64_VERSION; kind_sha=$KIND_AMD64_SHA256 ;;
    aarch64)
        arch=arm64; bun_arch=aarch64
        bun_tag=$BUN_ARM64_VERSION; bun_sha=$BUN_ARM64_SHA256
        kind_tag=$KIND_ARM64_VERSION; kind_sha=$KIND_ARM64_SHA256 ;;
    *) echo 'Supported architectures: amd64 and arm64' >&2; exit 1 ;;
esac

download_dir=$(mktemp -d)
trap 'rm -r -- "$download_dir"' EXIT

curl --fail --location --retry 3 \
    "https://github.com/oven-sh/bun/releases/download/${bun_tag}/bun-linux-${bun_arch}.zip" \
    -o "$download_dir/bun.zip"
printf '%s  %s\n' "$bun_sha" "$download_dir/bun.zip" | sha256sum -c -
unzip -q "$download_dir/bun.zip" -d "$download_dir/bun"
install -m 755 "$download_dir/bun/bun-linux-${bun_arch}/bun" /usr/local/bin/bun

curl --fail --location --retry 3 \
    "https://github.com/kubernetes-sigs/kind/releases/download/${kind_tag}/kind-linux-${arch}" \
    -o "$download_dir/kind"
printf '%s  %s\n' "$kind_sha" "$download_dir/kind" | sha256sum -c -
install -m 755 "$download_dir/kind" /usr/local/bin/kind

npm install --global --ignore-scripts=false --min-release-age=0 --no-audit \
    "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" \
    "@openai/codex@${CODEX_VERSION}" \
    "@earendil-works/pi-coding-agent@${PI_VERSION}" \
    "opencode-ai@${OPENCODE_VERSION}" \
    "pnpm@${PNPM_VERSION}"
for agent in claude codex pi opencode pnpm; do
    "$agent" --version
done

# Generate static completion files once; the drop-in initializes their loader.
# Keep Fedora's packaged completions, including kubectl when available.
completions=/usr/share/bash-completion/completions
codex completion bash > "$completions/codex"
kind completion bash > "$completions/kind"
if [[ ! -f $completions/kubectl ]]; then
    kubectl completion bash > "$completions/kubectl"
fi
opencode completion > "$completions/opencode"
npm completion > "$completions/npm"
pnpm completion bash > "$completions/pnpm"
for completion in codex kind kubectl opencode npm pnpm; do
    bash -n "$completions/$completion"
done

# Let dev read shared Composer metadata without trying to create it.
printf '{}\n' > /etc/composer/auth.json
printf '{}\n' > /etc/composer/composer.json

npm cache clean --force
# Remove only the helper scratch directory created by build-time Codex checks.
if [[ -d /root/.codex/tmp/arg0-linux ]]; then
    rm -r /root/.codex/tmp/arg0-linux
fi
