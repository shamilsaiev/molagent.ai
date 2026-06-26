#!/usr/bin/env bash
# pi-molagent — one-liner installer
#
# Usage:
#   curl -fsSL https://molagent.ai/install.sh | bash
#
# What this script does:
#   1. Verifies Node.js (>=18) + npm are present. Exits with instructions
#      if missing (we will NOT auto-install Node — that is your decision).
#   2. Installs the pi coding agent globally via npm if it's not on PATH.
#   3. Installs the molagent ecosystem of pi extensions, skipping any
#      that are already registered with `pi list`:
#         - npm:pi-web-access
#         - npm:@juicesharp/rpiv-ask-user-question
#         - npm:pi-powerline-footer
#         - git:github.com/avatsaev/pi-molagent
#
# Safe to re-run: every step is idempotent. No sudo. No PATH edits.
#
# NOTE on the pi-molagent repo: it is currently a private GitHub repository.
# This script tries HTTPS first and falls back to SSH if HTTPS clone fails
# (typical reason: no GitHub HTTPS token / credential helper). The SSH
# fallback requires a GitHub SSH key on this machine
# (verify with `ssh -T git@github.com`).
#
# Customisation via environment variables:
#   MOLAGENT_REF=main                # git ref / tag / commit for pi-molagent
#   MOLAGENT_LOCAL=1                 # use `pi install -l` (project-local)
#   MOLAGENT_AUTH=https|ssh|auto     # force one auth method; default 'auto'
#                                    # tries https then falls back to ssh
#
# Exit codes:
#   0  success
#   1  Node.js / npm missing
#   2  pi install failed
#   3  extension install failed

set -euo pipefail

# ---------- pretty output ---------------------------------------------------

if [[ -t 1 ]] && command -v tput >/dev/null 2>&1 && [[ $(tput colors 2>/dev/null || echo 0) -ge 8 ]]; then
    C_BOLD=$(tput bold); C_DIM=$(tput dim); C_RESET=$(tput sgr0)
    C_GREEN=$(tput setaf 2); C_YELLOW=$(tput setaf 3); C_RED=$(tput setaf 1); C_BLUE=$(tput setaf 4)
else
    C_BOLD=""; C_DIM=""; C_RESET=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_BLUE=""
fi

say()   { printf '%s\n' "$*"; }
info()  { printf '%s==>%s %s\n' "$C_BLUE$C_BOLD" "$C_RESET" "$*"; }
ok()    { printf '  %s✓%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
skip()  { printf '  %s•%s %s %s(already installed)%s\n' "$C_DIM" "$C_RESET" "$*" "$C_DIM" "$C_RESET"; }
warn()  { printf '  %s!%s %s\n' "$C_YELLOW$C_BOLD" "$C_RESET" "$*" >&2; }
fail()  { printf '%sERROR:%s %s\n' "$C_RED$C_BOLD" "$C_RESET" "$*" >&2; }

# ---------- 1. Node + npm check --------------------------------------------

info "Checking prerequisites"

if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
    fail "Node.js and/or npm not found on PATH."
    say  ""
    say  "pi-molagent depends on the pi coding agent, which is an npm package."
    say  "Install Node.js 18+ (LTS recommended) first, then re-run this script."
    say  ""
    say  "  • Official installers:   https://nodejs.org/"
    say  "  • Linux (recommended):   https://github.com/nvm-sh/nvm"
    say  "      curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash"
    say  "      nvm install --lts"
    say  "  • macOS (Homebrew):      brew install node"
    say  "  • Debian/Ubuntu:         sudo apt install nodejs npm"
    say  ""
    exit 1
fi

NODE_VERSION=$(node --version | sed 's/^v//')
NODE_MAJOR=${NODE_VERSION%%.*}
if (( NODE_MAJOR < 18 )); then
    fail "Node.js $NODE_VERSION is too old; the pi coding agent requires Node 18+."
    say  "Upgrade via your package manager or nvm (\`nvm install --lts\`) and re-run."
    exit 1
fi
ok "node $NODE_VERSION  ($(command -v node))"
ok "npm  $(npm --version)  ($(command -v npm))"

# ---------- 2. pi coding agent ---------------------------------------------

info "Installing pi coding agent"

if command -v pi >/dev/null 2>&1 && pi --version >/dev/null 2>&1; then
    PI_VERSION=$(pi --version 2>/dev/null | head -n1)
    skip "pi $PI_VERSION"
else
    if ! npm install -g @earendil-works/pi-coding-agent; then
        fail "npm install -g @earendil-works/pi-coding-agent failed."
        say  ""
        say  "If you saw an EACCES permission error, your npm prefix points at a"
        say  "system path. Recommended fix: install Node via nvm so global npm"
        say  "packages land in your \$HOME (no sudo needed). See:"
        say  "  https://github.com/nvm-sh/nvm"
        exit 2
    fi
    ok "pi installed → $(command -v pi || true)"
fi

# ---------- 3. molagent extensions -----------------------------------------

info "Installing molagent pi extensions"

MOLAGENT_REF="${MOLAGENT_REF:-}"
MOLAGENT_AUTH="${MOLAGENT_AUTH:-auto}"   # auto | https | ssh

# Build the candidate spec list for pi-molagent. With auto (default) we try
# HTTPS first and fall back to SSH; with explicit https/ssh we try just one.
_molagent_spec() {
    local repo="$1"
    if [[ -n "$MOLAGENT_REF" ]]; then
        printf 'git:%s@%s' "$repo" "$MOLAGENT_REF"
    else
        printf 'git:%s' "$repo"
    fi
}
MOLAGENT_HTTPS_SPEC=$(_molagent_spec "github.com/avatsaev/pi-molagent")
MOLAGENT_SSH_SPEC=$(_molagent_spec   "git@github.com:avatsaev/pi-molagent")

case "$MOLAGENT_AUTH" in
    auto)  MOLAGENT_CANDIDATES=("$MOLAGENT_HTTPS_SPEC" "$MOLAGENT_SSH_SPEC") ;;
    https) MOLAGENT_CANDIDATES=("$MOLAGENT_HTTPS_SPEC") ;;
    ssh)   MOLAGENT_CANDIDATES=("$MOLAGENT_SSH_SPEC") ;;
    *)     fail "MOLAGENT_AUTH must be one of: auto | https | ssh (got: $MOLAGENT_AUTH)"; exit 2 ;;
esac

EXTENSIONS=(
    "npm:pi-web-access"
    "npm:@juicesharp/rpiv-ask-user-question"
    "npm:pi-powerline-footer"
    "__MOLAGENT__"   # sentinel; expanded into MOLAGENT_CANDIDATES below
)

# Optional project-local install
PI_INSTALL_FLAGS=()
if [[ "${MOLAGENT_LOCAL:-}" == "1" ]]; then
    PI_INSTALL_FLAGS+=("-l")
    warn "MOLAGENT_LOCAL=1 — installing into ./.pi/ (project-local)"
fi

# Cache `pi list` once for idempotency lookups.
PI_LIST_OUTPUT=$(pi list 2>/dev/null || true)

is_installed() {
    # Recognise a package as installed if `pi list` contains EITHER:
    #   (a) the exact spec  (npm:foo, git:host/user/repo)
    #   (b) the spec without a trailing @ref
    #   (c) for git specs, the path basename — covers local-path installs
    #       like `pi install /home/me/dev/pi-molagent`, which `pi list`
    #       displays as a relative or absolute filesystem path.
    local spec="$1"
    local bare_spec="${spec%@*}"

    if grep -Fq -e "$spec" -e "$bare_spec" <<<"$PI_LIST_OUTPUT"; then
        return 0
    fi

    if [[ "$spec" == git:* ]]; then
        # git:github.com/avatsaev/pi-molagent  →  pi-molagent
        local repo_basename="${bare_spec##*/}"
        # Look for the basename appearing as a path component in `pi list`
        # (paths show up indented under the package name).
        if grep -Eq "(^|/)${repo_basename}( |$)" <<<"$PI_LIST_OUTPUT"; then
            return 0
        fi
    fi

    return 1
}

# Install a single extension spec. Returns 0 on success, non-zero on failure.
install_extension() {
    local ext="$1"
    say  "  → pi install ${PI_INSTALL_FLAGS[*]:-}$ext"
    pi install "${PI_INSTALL_FLAGS[@]}" "$ext"
}

# Install pi-molagent with HTTPS → SSH failover.
# Checks idempotency against ALL candidate specs plus local-path installs.
install_molagent() {
    local cand
    for cand in "${MOLAGENT_CANDIDATES[@]}"; do
        if is_installed "$cand"; then
            skip "$cand"
            return 0
        fi
    done

    local last_err=0
    for cand in "${MOLAGENT_CANDIDATES[@]}"; do
        if install_extension "$cand"; then
            ok "$cand"
            return 0
        fi
        last_err=$?
        local _last_idx=$(( ${#MOLAGENT_CANDIDATES[@]} - 1 ))
        if (( ${#MOLAGENT_CANDIDATES[@]} > 1 )) && [[ "$cand" != "${MOLAGENT_CANDIDATES[$_last_idx]}" ]]; then
            warn "$cand failed — trying SSH fallback"
        fi
    done
    return $last_err
}

INSTALL_FAILED=0
for ext in "${EXTENSIONS[@]}"; do
    if [[ "$ext" == "__MOLAGENT__" ]]; then
        if ! install_molagent; then
            warn "failed to install pi-molagent via any auth method"
            INSTALL_FAILED=1
        fi
        continue
    fi

    if is_installed "$ext"; then
        skip "$ext"
        continue
    fi

    if install_extension "$ext"; then
        ok "$ext"
    else
        warn "failed to install $ext (continuing with the rest)"
        INSTALL_FAILED=1
    fi
done

if (( INSTALL_FAILED == 1 )); then
    fail "One or more extensions failed to install. See messages above."
    exit 3
fi

# ---------- 4. done ---------------------------------------------------------

cat <<EOF

${C_GREEN}${C_BOLD}✓ pi-molagent installation complete.${C_RESET}

Next steps:
  1. ${C_BOLD}Activate steering rules${C_RESET}
       pi list                       # find the install path
       ln -s <install-path>/steering/AGENTS.md ~/.pi/agent/AGENTS.md

  2. ${C_BOLD}Generate molagent.json${C_RESET}
       pi
       > /molagent:init
       > /molagent:doctor            # verify external-tool paths

  3. ${C_BOLD}Documentation${C_RESET}
       https://molagent.avatsaev.com/docs.html
       https://github.com/avatsaev/pi-molagent

EOF
