# Restore shared defaults for shells whose environment was cleared.
[ -n "${BASH_VERSION-}" ] || return 0
while IFS='=' read -r dev_name dev_value; do
    case $dev_name in ''|\#*) continue ;; esac
    if [[ ! -v $dev_name ]]; then
        printf -v "$dev_name" '%s' "$dev_value"
    fi
    export "$dev_name"
done < /etc/dev-environment.env
unset dev_name dev_value

# Fedora sources profile.d from /etc/profile or /etc/bashrc, as appropriate.
# Prepend the default user install directories once, even before they exist.
# No GOPATH, CARGO_HOME, BUN_INSTALL or UV_TOOL_BIN_DIR override is needed.
for dev_bin in "$HOME/go/bin" "$HOME/.cargo/bin" "$HOME/.bun/bin" \
    "$HOME/bin" "$HOME/.local/bin"; do
    case ":$PATH:" in
        *:"$dev_bin":*) ;;
        *) PATH="$dev_bin:$PATH" ;;
    esac
done
unset dev_bin

# Add administrative and shared Composer tools without replacing caller paths.
for dev_bin in /usr/local/sbin /usr/sbin "$COMPOSER_HOME/vendor/bin"; do
    case ":$PATH:" in
        *:"$dev_bin":*) ;;
        *) PATH="$PATH:$dev_bin" ;;
    esac
done
unset dev_bin
export PATH

# The environment above also applies to non-interactive login shells.
# Keep Bash-only settings out of other shells and scripts.
case $- in
    *i*) ;;
    *) return 0 ;;
esac

# Fedora's loader honors user preferences and guards against double loading.
. /etc/profile.d/bash_completion.sh

HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoreboth
shopt -s histappend checkwinsize

# Save each command and pick up history from other open shells.
if [[ " ${PROMPT_COMMAND[*]} " != *" history -a; history -n "* ]]; then
    PROMPT_COMMAND+=('history -a; history -n')
fi

alias ll='ls -alF'
PS1='[\u@\h \w]\$ '
