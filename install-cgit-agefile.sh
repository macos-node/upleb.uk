#!/bin/sh
# install-cgit-agefile.sh
#
# Wires up cgit's "Idle" column for ngit-grasp's bare repos.
#
# 1. Drops a `post-receive` hook into a system template dir, then points
#    ngit-grasp's service env at it via GIT_TEMPLATE_DIR. Future repos
#    created by `git init --bare` will inherit the hook automatically.
# 2. Installs the hook into each existing bare repo at $DATA_DIR/*/*.git.
# 3. Backfills info/web/last-modified from each repo's most recent commit
#    timestamp so the Idle column shows sensible values immediately.
# 4. Purges cgit's CGI cache.
#
# Run on the server as root. Idempotent — safe to re-run after deploying
# new repos or if the template hook gets out of sync.

set -eu

DATA_DIR=/opt/ngit-grasp/data/git
TEMPLATE_DIR=/etc/git-templates-upleb
ENV_FILE=/opt/ngit-grasp/.env
OWNER=ngit-grasp:ngit-grasp
HOOK_SRC=/usr/local/share/upleb/cgit-post-receive   # populated by the deploy step before this script runs

if [ ! -r "$HOOK_SRC" ]; then
    echo "error: hook source not found at $HOOK_SRC" >&2
    echo "       scp ~/code_upleb/upleb.uk/cgit-post-receive root@server:$HOOK_SRC first" >&2
    exit 1
fi

echo "1) Installing template hook"
mkdir -p "$TEMPLATE_DIR/hooks"
install -m 0755 "$HOOK_SRC" "$TEMPLATE_DIR/hooks/post-receive"
echo "   $TEMPLATE_DIR/hooks/post-receive"

echo "2) Pointing ngit-grasp at GIT_TEMPLATE_DIR"
if grep -q '^GIT_TEMPLATE_DIR=' "$ENV_FILE" 2>/dev/null; then
    sed -i "s|^GIT_TEMPLATE_DIR=.*|GIT_TEMPLATE_DIR=$TEMPLATE_DIR|" "$ENV_FILE"
else
    printf '\n# cgit Idle column: post-receive hook for new bare repos.\nGIT_TEMPLATE_DIR=%s\n' "$TEMPLATE_DIR" >> "$ENV_FILE"
fi
systemctl restart ngit-grasp

echo "3) Installing hook + backfilling agefile in existing repos:"
for d in "$DATA_DIR"/*/*.git; do
    [ -d "$d" ] || continue
    install -m 0755 "$HOOK_SRC" "$d/hooks/post-receive"
    mkdir -p "$d/info/web"
    # cgit parses the FIRST LINE as an RFC2822 date, so we write a date
    # string rather than relying on file mtime. Backfill from the most
    # recent commit on HEAD; fall back to "now" if the repo has no HEAD.
    ts=$(git -c "safe.directory=$d" -C "$d" log -1 --format=%cD HEAD 2>/dev/null || true)
    if [ -n "$ts" ]; then
        printf '%s\n' "$ts" > "$d/info/web/last-modified"
        printf '   ✓ %-90s  %s\n' "$(basename "$(dirname "$d")")/$(basename "$d")" "$ts"
    else
        date -u -R > "$d/info/web/last-modified"
        printf '   ! %-90s  (no HEAD commit; agefile=now)\n' "$(basename "$(dirname "$d")")/$(basename "$d")"
    fi
    chown -R "$OWNER" "$d/hooks" "$d/info/web"
done

echo "4) Purging cgit cache"
find /var/cache/cgit -mindepth 1 -delete 2>/dev/null || true

echo
echo "Done."
