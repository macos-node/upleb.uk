#!/usr/bin/env bash
# Bootstrap cgit at upleb.uk on the server. Run as root: bash server-bootstrap-cgit.sh
# Idempotent — safe to re-run.
#
# REPLACES the existing upleb.uk vhost (LND topology viz). Old vhost backed up to
# /etc/nginx/sites-available/upleb.uk.lnd-viz.bak.
set -euo pipefail

SCAFFOLD_DIR="$(cd "$(dirname "$0")" && pwd)"
NIP05_DIR="/home/upleb/upleb-nip05"

echo "==> 1/6 Install cgit + fcgiwrap (Debian)"
apt-get update
apt-get -y install cgit fcgiwrap

echo "==> 2/6 Install /etc/cgitrc + cache dir"
cp "${SCAFFOLD_DIR}/cgitrc" /etc/cgitrc
mkdir -p /var/cache/cgit
chown www-data:www-data /var/cache/cgit
chmod 750 /var/cache/cgit

# Install upleb-themed static assets alongside cgit's own (served via
# nginx alias /cgit-css/ -> /usr/share/cgit/). cgitrc references these
# under /cgit-css/{upleb.css,favicon.ico,favicon.svg}.
install -m 644 "${SCAFFOLD_DIR}/upleb.css"              /usr/share/cgit/upleb.css
install -m 644 "${SCAFFOLD_DIR}/upleb-header.html"       /usr/share/cgit/upleb-header.html
install -m 644 "${SCAFFOLD_DIR}/upleb-head-include.html" /usr/share/cgit/upleb-head-include.html
install -m 644 "${SCAFFOLD_DIR}/favicon.ico"             /usr/share/cgit/favicon.ico
install -m 644 "${SCAFFOLD_DIR}/favicon.svg"             /usr/share/cgit/favicon.svg

echo "==> 3/6 NIP-05 dir for upleb.uk (host-side)"
mkdir -p "${NIP05_DIR}"
chown -R upleb:upleb "${NIP05_DIR}"
[ -f "${NIP05_DIR}/nostr.json" ] || echo '{"names":{}}' > "${NIP05_DIR}/nostr.json"

echo "==> 4/6 Backup old upleb.uk vhost (LND viz) + install new (cgit)"
if [ -f /etc/nginx/sites-available/upleb.uk ] \
   && ! grep -q "fcgiwrap.socket" /etc/nginx/sites-available/upleb.uk; then
  cp /etc/nginx/sites-available/upleb.uk \
     /etc/nginx/sites-available/upleb.uk.lnd-viz.bak
fi
cp "${SCAFFOLD_DIR}/nginx-upleb.uk.conf" /etc/nginx/sites-available/upleb.uk

echo "==> 5/6 Enable + start fcgiwrap socket"
systemctl enable --now fcgiwrap.socket
ls -la /run/fcgiwrap.socket || true

echo "==> 6/6 nginx -t + reload"
nginx -t && systemctl reload nginx

echo ""
echo "Done. Verify:"
echo "  curl -sL https://upleb.uk | head -20    # should show cgit HTML"
echo "  curl -sI https://upleb.uk/cgit-css/cgit.css   # 200 OK"
echo ""
echo "If you push a repo via ngit, it'll appear under /opt/ngit-relay/volumes/repos/"
echo "and cgit will auto-discover it on next request (cache TTL 5 min)."
echo ""
echo "Old LND-viz vhost saved at /etc/nginx/sites-available/upleb.uk.lnd-viz.bak"
echo "and the static dist still lives at /var/www/html/ untouched."
