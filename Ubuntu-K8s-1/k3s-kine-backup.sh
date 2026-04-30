#!/bin/bash
set -euo pipefail

SRC=/var/lib/rancher/k3s/server/db/state.db
DEST_DIR=/mnt/External/Backup/K8s/k3s-kine
RETENTION_DAYS=14
TIMESTAMP=$(date -u +%Y%m%dT%H%M%SZ)
TMP=$(mktemp --suffix=.db)
OUT="${DEST_DIR}/kine-${TIMESTAMP}.db.gz"

trap 'rm -f "$TMP"' EXIT

mkdir -p "$DEST_DIR"

sqlite3 "$SRC" ".backup '$TMP'"
sqlite3 "$TMP" "PRAGMA integrity_check;" | head -1 | grep -qx ok

gzip -c "$TMP" > "${OUT}.partial"
mv "${OUT}.partial" "$OUT"

find "$DEST_DIR" -type f -name 'kine-*.db.gz' -mtime +${RETENTION_DAYS} -delete

echo "kine snapshot ok: $OUT ($(stat -c%s "$OUT") bytes)"
