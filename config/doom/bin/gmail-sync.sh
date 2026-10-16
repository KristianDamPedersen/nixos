#!/usr/bin/env bash
set -euo pipefail
umask 077

# Emacs prepends this sendmail compatibility flag.
if [[ "${1:-}" == "-oi" ]]; then
    shift
fi

action=${1:-sync}
if (( $# > 0 )); then
    shift
fi

case "$action" in
    init|sync|send) ;;
    *)
        echo "Expected init, sync or send." >&2
        exit 2
        ;;
esac

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
manifest="$script_dir/../secretspec.toml"
repository="$HOME/.mail/account.gmail"
credentials="$repository/.credentials.gmailieer.json"

secret() {
    secretspec --file "$manifest" "$@" \
        --profile default \
        --provider onepassword://Private 9>&-
}

export NOTMUCH_CONFIG=/etc/notmuch-config
mkdir -p "$repository"
cd "$repository"

# Keep the lock in this shell; close fd 9 for children so background daemons
# cannot keep it locked after the wrapper exits.
# Prevent concurrent runs of this wrapper
exec 9> .secretspec-sync.lock
flock -n 9 || {
    echo "Another Gmail sync wrapper is running." >&2
    exit 1
}

# Never overwrite existing or interrupted authorization data.
for path in "$credentials" "$credentials.new"; do
    if [[ -e "$path" || -L "$path" ]]; then
        echo "Existing credential file needs attention: $path" >&2
        exit 1
    fi
done

# Prepare the local database and Lieer repositoryunder the existing lock.
if [[ ! -d "$HOME/.mail/.notmuch" ]]; then
    notmuch new 9>&-
fi

if [[ ! -e .gmailieer.json ]]; then
    gmi init --no-auth kristian.dam.pedersen@gmail.com 9>&-
fi

# Reapply on each run so an interrupted initialization is recoverable.
# Emacs treats any sendmail output as failure, even with a zero exit status.
# `gmi set` always prints settings; keep diagnostics on stderr visible.
gmi set --no-remove-local-messages > /dev/null 9>&-

# Opening mail only needs local initialization.
if [[ "$action" == init ]]; then
    exit 0
fi

snapshot=$(mktemp "$repository/.secretspec-credentials.XXXXXX")
trap 'rm -f -- "$snapshot"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

secret get GMAIL_CREDENTIALS < /dev/null > "$snapshot"
if [[ ! -s "$snapshot" ]]; then
    echo "SecretSpec returned empty credentials." >&2
    exit 1
fi

# noclobber prevents overwriting a file created since the check.
(set -o noclobber; cat "$snapshot" > "$credentials")

sync_status=0
gmi "$action" "$@" 9>&- || sync_status=$?

if [[ -e "$credentials.new" ]]; then
    echo "Lieer left an incomplete credential update; keeping files for recovery." >&2
    exit 1
fi

if [[ ! -s "$credentials" ]]; then
    echo "Lieer's credential file is missing or empty; stopping." >&2
    exit 1
fi

if ! cmp -s "$snapshot" "$credentials"; then
    if ! secret set GMAIL_CREDENTIALS < "$credentials"; then
        echo "Could not save updated credentials to 1Password." >&2
        echo "Keeping local credential file for recovery." >&2
        exit 1
    fi
fi

rm -- "$credentials"

if (( sync_status != 0 )); then
    exit "$sync_status"
fi

if [[ "$action" == sync ]]; then
    notmuch new 9>&-
fi
