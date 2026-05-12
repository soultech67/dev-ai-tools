#!/usr/bin/env bash
# =============================================================================
# dev-ai-tools — install_serena.sh
# Idempotent installer for Serena: https://github.com/oraios/serena
#
# Serena is installed as a uv-managed tool:
#   uv tool install -p 3.13 serena-agent@latest --prerelease=allow
#
# This script only installs or updates the Serena CLI. Client MCP wiring remains
# in install.sh so each client can receive the resolved executable path.
# =============================================================================
set -euo pipefail

info()    { echo "  [·] $*"; }
ok()      { echo "  [✓] $*"; }
warn()    { echo "  [!] $*"; }
section() { echo; echo "── $* ──────────────────────────────────────────────"; }

SERENA_PACKAGE="${SERENA_PACKAGE:-serena-agent@latest}"
SERENA_TOOL_NAME="${SERENA_TOOL_NAME:-serena-agent}"
SERENA_PYTHON="${SERENA_PYTHON:-3.13}"
SERENA_PRERELEASE="${SERENA_PRERELEASE:-allow}"
_serena_expected=false
_serena_install_attempted=false

prompt_yes_no() {
  local prompt="$1"
  local default_answer="$2"
  local answer

  if [[ -t 0 ]]; then
    read -r -p "$prompt" answer || answer="$default_answer"
  else
    answer="$default_answer"
    info "No interactive input; using default '$default_answer' for: $prompt"
  fi

  answer="${answer:-$default_answer}"
  [[ "$answer" =~ ^[Yy] ]]
}

serena_version() {
  serena --version 2>/dev/null | head -1 || echo "version unknown"
}

serena_uv_tool_installed() {
  uv tool list 2>/dev/null | grep -Eq "^${SERENA_TOOL_NAME}([[:space:]]|$)"
}

install_serena() {
  _serena_expected=true
  _serena_install_attempted=true
  uv tool install -p "$SERENA_PYTHON" "$SERENA_PACKAGE" "--prerelease=$SERENA_PRERELEASE"
}

upgrade_serena() {
  uv tool upgrade -p "$SERENA_PYTHON" "$SERENA_TOOL_NAME" "--prerelease=$SERENA_PRERELEASE"
}

section "Serena (semantic code intelligence MCP)"

if ! command -v uv &>/dev/null; then
  warn "uv not found — Serena is installed via:"
  warn "  uv tool install -p $SERENA_PYTHON $SERENA_PACKAGE --prerelease=$SERENA_PRERELEASE"
  warn "Run 'make setup' first (it installs uv), or install uv manually:"
  warn "  curl -LsSf https://astral.sh/uv/install.sh | sh"
  exit 1
fi

ok "uv: $(uv --version)"

_serena_on_path=false
if command -v serena &>/dev/null; then
  _serena_on_path=true
  _serena_expected=true
  ok "serena already available: $(serena_version)"
fi

if serena_uv_tool_installed; then
  _serena_expected=true
  if [[ "${DEV_AI_TOOLS_SKIP_SERENA_UPGRADE:-0}" == "1" ]]; then
    info "Serena already installed — skipping upgrade check."
  elif prompt_yes_no "  Update Serena (uv tool upgrade $SERENA_TOOL_NAME)? [y/N] " "N"; then
    upgrade_serena || warn "uv tool upgrade returned non-zero; continuing"
  else
    info "Keeping current Serena version."
  fi
elif $_serena_on_path; then
  warn "'serena' exists on PATH but does not appear to be managed by uv tool."
  warn "  Path: $(command -v serena)"
  if prompt_yes_no "  Install uv-managed Serena anyway? [y/N] " "N"; then
    install_serena
  else
    info "Skipped uv-managed Serena install."
  fi
else
  if prompt_yes_no "  Install Serena (uv tool install -p $SERENA_PYTHON $SERENA_PACKAGE --prerelease=$SERENA_PRERELEASE)? [Y/n] " "Y"; then
    install_serena
  else
    info "Skipped Serena install."
  fi
fi

# Re-source PATH in case uv tool install dropped a shim into ~/.local/bin.
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

if command -v serena &>/dev/null; then
  ok "serena: $(serena_version)"
elif $_serena_expected; then
  _uv_tool_bin="$(uv tool dir --bin 2>/dev/null || echo "$HOME/.local/bin")"
  if $_serena_install_attempted; then
    warn "Serena install ran, but 'serena' is not on PATH."
  else
    warn "Serena appears to be installed, but 'serena' is not on PATH."
  fi
  warn "  Add the uv tool bin directory to PATH:"
  warn "    export PATH=\"$_uv_tool_bin:\$PATH\""
  warn "  or run: uv tool update-shell"
  exit 1
else
  info "Serena CLI not installed."
fi
