#!/usr/bin/env bash
# One-click OpenClaw server upgrade script.
#
# Detects the active install type and upgrades accordingly:
#   npm   — updates the global npm package, runs doctor, restarts the gateway
#   git   — git pull --rebase, pnpm install + build, runs doctor, restarts
#   docker-remote — docker pull, docker compose up --force-recreate
#   docker-local  — git pull --rebase, rebuild image, docker compose up
#
# Usage:
#   ./scripts/upgrade-server.sh [--channel stable|beta|dev] [--tag <ref>]
#                                [--dry-run] [--help]
#
# Environment variables (all optional):
#   OPENCLAW_UPGRADE_CHANNEL  — npm channel override (stable|beta|dev)
#   OPENCLAW_UPGRADE_TAG      — git ref / npm tag override
#   OPENCLAW_IMAGE            — Docker image name (default: openclaw:local)
#   OPENCLAW_GATEWAY_TOKEN    — passed to health check when set
#   OPENCLAW_GATEWAY_PORT     — gateway port for health check (default: 18789)
#   OPENCLAW_DRY_RUN          — set to 1 to preview without applying

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ── Helpers ────────────────────────────────────────────────────────────────────

log()  { printf '==> %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }
ok()   { printf 'OK: %s\n' "$*"; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

run_step() {
  local label="$1"; shift
  log "$label"
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    info "(dry-run) would run: $*"
    return 0
  fi
  if ! "$@"; then
    fail "$label failed"
  fi
}

# ── Argument parsing ───────────────────────────────────────────────────────────

CHANNEL="${OPENCLAW_UPGRADE_CHANNEL:-}"
TAG_REF="${OPENCLAW_UPGRADE_TAG:-}"
DRY_RUN="${OPENCLAW_DRY_RUN:-0}"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --channel <stable|beta|dev>   Update to a specific channel (npm installs)
  --tag <ref>                   Update to a specific git ref or npm tag
  --dry-run                     Preview steps without applying changes
  -h, --help                    Show this help

Environment variables:
  OPENCLAW_UPGRADE_CHANNEL      Same as --channel
  OPENCLAW_UPGRADE_TAG          Same as --tag
  OPENCLAW_IMAGE                Docker image name (default: openclaw:local)
  OPENCLAW_GATEWAY_TOKEN        Gateway auth token for health check
  OPENCLAW_GATEWAY_PORT         Gateway port (default: 18789)
  OPENCLAW_DRY_RUN              Set to 1 for dry-run mode
EOF
}

for arg in "$@"; do
  case "$arg" in
    --channel=*) CHANNEL="${arg#--channel=}" ;;
    --channel)   ;;
    --tag=*)     TAG_REF="${arg#--tag=}" ;;
    --tag)       ;;
    --dry-run)   DRY_RUN=1 ;;
    -h|--help)   usage; exit 0 ;;
    *)           ;;
  esac
done

# Handle --channel <value> and --tag <value> (space-separated)
prev=""
for arg in "$@"; do
  if [[ "$prev" == "--channel" ]]; then CHANNEL="$arg"; fi
  if [[ "$prev" == "--tag" ]]; then TAG_REF="$arg"; fi
  prev="$arg"
done

[[ "${DRY_RUN}" == "1" ]] && log "DRY-RUN mode — no changes will be applied"

# ── Install-type detection ─────────────────────────────────────────────────────

INSTALL_TYPE=""
IMAGE_NAME="${OPENCLAW_IMAGE:-openclaw:local}"
COMPOSE_FILE="$ROOT_DIR/docker-compose.yml"

detect_install_type() {
  # 1. Docker: compose file present and docker compose is available
  if [[ -f "$COMPOSE_FILE" ]] && command -v docker >/dev/null 2>&1 \
      && docker compose version >/dev/null 2>&1; then
    if [[ "$IMAGE_NAME" == "openclaw:local" ]]; then
      INSTALL_TYPE="docker-local"
    else
      INSTALL_TYPE="docker-remote"
    fi
    return
  fi

  # 2. Git source checkout: .git present and pnpm available
  if [[ -d "$ROOT_DIR/.git" ]] && command -v pnpm >/dev/null 2>&1; then
    INSTALL_TYPE="git"
    return
  fi

  # 3. npm global install (fallback)
  if command -v openclaw >/dev/null 2>&1; then
    INSTALL_TYPE="npm"
    return
  fi

  fail "Could not detect OpenClaw install type. Ensure openclaw is installed or run from the repo root."
}

detect_install_type
log "Detected install type: ${INSTALL_TYPE}"

# ── Upgrade paths ──────────────────────────────────────────────────────────────

upgrade_npm() {
  local update_args=()
  [[ -n "$CHANNEL" ]] && update_args+=(--channel "$CHANNEL")
  [[ -n "$TAG_REF" ]] && update_args+=(--tag "$TAG_REF")

  if command -v openclaw >/dev/null 2>&1 && openclaw update --help >/dev/null 2>&1; then
    # Prefer the built-in updater when available.
    run_step "Update via openclaw update" openclaw update "${update_args[@]}"
  else
    # Fallback: direct npm install.
    local pkg="openclaw"
    if [[ -n "$TAG_REF" ]]; then
      pkg="openclaw@${TAG_REF}"
    elif [[ "$CHANNEL" == "beta" ]]; then
      pkg="openclaw@beta"
    elif [[ -n "$CHANNEL" && "$CHANNEL" != "stable" ]]; then
      pkg="openclaw@${CHANNEL}"
    else
      pkg="openclaw@latest"
    fi
    run_step "Install $pkg (npm)" npm install -g "$pkg"
    run_step "Run doctor" openclaw doctor
    run_step "Restart gateway" openclaw gateway restart
  fi
}

upgrade_git() {
  local git_ref="${TAG_REF:-}"

  run_step "Fetch latest" git -C "$ROOT_DIR" fetch origin

  if [[ -n "$git_ref" ]]; then
    run_step "Checkout $git_ref" git -C "$ROOT_DIR" checkout "$git_ref"
  else
    run_step "Pull latest (rebase)" git -C "$ROOT_DIR" pull --rebase origin "$(git -C "$ROOT_DIR" rev-parse --abbrev-ref HEAD)"
  fi

  run_step "Install dependencies" bash -lc "cd '$ROOT_DIR' && pnpm install --frozen-lockfile"
  run_step "Build" bash -lc "cd '$ROOT_DIR' && pnpm build"
  run_step "Run doctor" bash -lc "cd '$ROOT_DIR' && node dist/index.js doctor"
  run_step "Restart gateway" bash -lc "cd '$ROOT_DIR' && node dist/index.js gateway restart"
}

run_docker_build() {
  DOCKER_BUILDKIT=1 docker build "$@"
}

upgrade_docker_local() {
  local git_ref="${TAG_REF:-}"

  run_step "Fetch latest" git -C "$ROOT_DIR" fetch origin

  if [[ -n "$git_ref" ]]; then
    run_step "Checkout $git_ref" git -C "$ROOT_DIR" checkout "$git_ref"
  else
    run_step "Pull latest (rebase)" git -C "$ROOT_DIR" pull --rebase origin "$(git -C "$ROOT_DIR" rev-parse --abbrev-ref HEAD)"
  fi

  log "Rebuilding Docker image: ${IMAGE_NAME}"
  if [[ "${DRY_RUN}" == "1" ]]; then
    info "(dry-run) would run: DOCKER_BUILDKIT=1 docker build -t ${IMAGE_NAME} -f ${ROOT_DIR}/Dockerfile ${ROOT_DIR}"
  else
    run_docker_build -t "$IMAGE_NAME" -f "$ROOT_DIR/Dockerfile" "$ROOT_DIR"
  fi

  run_step "Restart gateway container" \
    docker compose -f "$COMPOSE_FILE" up -d --force-recreate openclaw-gateway
}

upgrade_docker_remote() {
  log "Pulling Docker image: ${IMAGE_NAME}"
  if [[ "${DRY_RUN}" == "1" ]]; then
    info "(dry-run) would run: docker pull ${IMAGE_NAME}"
  else
    if ! docker pull "$IMAGE_NAME"; then
      fail "Failed to pull ${IMAGE_NAME}. Check the image name and your access permissions."
    fi
  fi

  run_step "Restart gateway container" \
    docker compose -f "$COMPOSE_FILE" up -d --force-recreate openclaw-gateway
}

# ── Health check ───────────────────────────────────────────────────────────────

check_health() {
  local port="${OPENCLAW_GATEWAY_PORT:-18789}"
  local token="${OPENCLAW_GATEWAY_TOKEN:-}"
  local url="http://127.0.0.1:${port}/healthz"

  log "Verifying gateway health at ${url}"
  if [[ "${DRY_RUN}" == "1" ]]; then
    info "(dry-run) would check: ${url}"
    return 0
  fi

  local attempt max_attempts=8 delay=3
  for ((attempt = 1; attempt <= max_attempts; attempt++)); do
    local status=0
    if command -v curl >/dev/null 2>&1; then
      local args=(-fsSo /dev/null -w "%{http_code}")
      [[ -n "$token" ]] && args+=(-H "Authorization: Bearer ${token}")
      local http_code
      http_code="$(curl "${args[@]}" "$url" 2>/dev/null)" || status=$?
      if [[ "$status" -eq 0 && "$http_code" =~ ^2 ]]; then
        ok "Gateway is healthy (HTTP ${http_code})"
        return 0
      fi
    elif command -v node >/dev/null 2>&1; then
      if node -e "fetch('${url}').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))" 2>/dev/null; then
        ok "Gateway is healthy"
        return 0
      fi
    else
      info "curl and node not found; skipping health check"
      return 0
    fi

    if [[ "$attempt" -lt "$max_attempts" ]]; then
      info "Not ready yet (attempt ${attempt}/${max_attempts}), retrying in ${delay}s..."
      sleep "$delay"
    fi
  done

  fail "Gateway did not become healthy after ${max_attempts} attempts. Check gateway logs."
}

# ── Main ───────────────────────────────────────────────────────────────────────

log "Starting OpenClaw server upgrade"
info "Install type : ${INSTALL_TYPE}"
info "Root dir     : ${ROOT_DIR}"
[[ -n "$CHANNEL" ]] && info "Channel      : ${CHANNEL}"
[[ -n "$TAG_REF" ]] && info "Tag/ref      : ${TAG_REF}"
echo ""

case "$INSTALL_TYPE" in
  npm)           upgrade_npm ;;
  git)           upgrade_git ;;
  docker-local)  upgrade_docker_local ;;
  docker-remote) upgrade_docker_remote ;;
  *)             fail "Unknown install type: ${INSTALL_TYPE}" ;;
esac

check_health

echo ""
ok "OpenClaw upgrade complete."
info "Run 'openclaw health' or 'openclaw doctor' if you encounter issues."
