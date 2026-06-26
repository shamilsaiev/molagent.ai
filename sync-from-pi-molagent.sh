#!/usr/bin/env bash
# sync-from-pi-molagent.sh
#
# Pull the latest docs, install script, and shared stylesheet from
# ../pi-molagent/site into this molagent.ai static website.
#
# What is synced (no other files are touched):
#   ../pi-molagent/site/docs/*.md   → ./docs/
#   ../pi-molagent/site/install.sh  → ./install.sh
#   ../pi-molagent/site/assets/style.css → ./assets/style.css
#
# Post-processing applied after every sync:
#   • Replace molagent.avatsaev.com/install.sh  →  molagent.ai/install.sh
#     in all copied files (docs/*.md, install.sh) so the public URL is correct.
#
# NOTE: docs.html is NOT touched — it uses the MolAgent branding and is
# maintained separately in this repo.
#
# Usage (from molagent.ai root):
#   ./sync-from-pi-molagent.sh
#
# Idempotent and safe to re-run.

set -euo pipefail

SITE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$(cd "${SITE_DIR}/../pi-molagent/site" && pwd)"

if [[ ! -d "${SRC}" ]]; then
  echo "ERROR: source directory not found: ${SRC}" >&2
  echo "       Expected pi-molagent to be a sibling of molagent.ai" >&2
  exit 1
fi

# ── 1. Sync docs/*.md ────────────────────────────────────────────────────

DOCS=(
  INSTALL.md
  CONFIG.md
  STEERING.md
  MIGRATION.md
  QUANTUM.md
)

mkdir -p "${SITE_DIR}/docs"
echo "syncing docs/*.md:"
for f in "${DOCS[@]}"; do
  src_file="${SRC}/docs/${f}"
  if [[ ! -f "${src_file}" ]]; then
    echo "  ! skip ${f} (missing in upstream)" >&2
    continue
  fi
  cp "${src_file}" "${SITE_DIR}/docs/${f}"
  echo "  + docs/${f}"
done

# ── 2. Sync install.sh ───────────────────────────────────────────────────

cp "${SRC}/install.sh" "${SITE_DIR}/install.sh"
echo "  + install.sh"

# ── 3. Sync assets/style.css ─────────────────────────────────────────────

mkdir -p "${SITE_DIR}/assets"
cp "${SRC}/assets/style.css" "${SITE_DIR}/assets/style.css"
echo "  + assets/style.css"

# ── 4. Post-process: rewrite old install URL → molagent.ai ───────────────

OLD_URL="https://molagent.avatsaev.com/install.sh"
NEW_URL="https://molagent.ai/install.sh"

echo
echo "rewriting install URL (molagent.avatsaev.com → molagent.ai):"

FILES_TO_PATCH=(
  "${SITE_DIR}/install.sh"
)

for f in "${DOCS[@]}"; do
  FILES_TO_PATCH+=("${SITE_DIR}/docs/${f}")
done

for f in "${FILES_TO_PATCH[@]}"; do
  if [[ -f "${f}" ]] && grep -q "${OLD_URL}" "${f}"; then
    sed -i "s|${OLD_URL}|${NEW_URL}|g" "${f}"
    echo "  ~ $(basename "${f}")"
  fi
done

# ── Done ─────────────────────────────────────────────────────────────────

echo
echo "sync complete."
echo "  source : ${SRC}"
echo "  target : ${SITE_DIR}"
