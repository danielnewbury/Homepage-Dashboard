#!/usr/bin/env bash
set -euo pipefail

########################################
# CONFIG
########################################
KEY_FILE="${HOME}/.config/age/key.txt"
ENC_FILE="./secrets.env.age"
PROJECT_DIR="$(pwd)"

########################################
# HELPERS
########################################
fail() {
  echo "❌ $1" >&2
  exit 1
}

info() {
  echo "▶ $1"
}

########################################
# PRE-FLIGHT CHECKS
########################################

# 1) Must supply a docker compose command
if [[ $# -eq 0 ]]; then
  fail "No docker compose command supplied.
Usage:
  ./run-compose.sh up -d
  ./run-compose.sh ps
  ./run-compose.sh logs -f"
fi

# 2) age installed
command -v age >/dev/null 2>&1 || fail "'age' is not installed"

# 3) Docker running
docker info >/dev/null 2>&1 || fail "Docker daemon is not running"

# 4) Compose available
docker compose version >/dev/null 2>&1 || fail "Docker Compose v2 not available"

# 5) Key file exists and is readable
[[ -f "$KEY_FILE" ]] || fail "Age key not found: $KEY_FILE"
[[ -r "$KEY_FILE" ]] || fail "Age key not readable: $KEY_FILE"

# 6) Encrypted secrets exist
[[ -f "$ENC_FILE" ]] || fail "Encrypted secrets file missing: $ENC_FILE"

info "Pre-flight checks passed"

########################################
# DECRYPT SECRETS (SECURELY)
########################################
tmp_env="$(mktemp)"
chmod 600 "$tmp_env"

cleanup() {
  shred -u "$tmp_env" 2>/dev/null || rm -f "$tmp_env"
}
trap cleanup EXIT

info "Decrypting secrets"

# Decrypt
age -d -i "$KEY_FILE" -o "$tmp_env" "$ENC_FILE" \
  || fail "Failed to decrypt secrets"

# 7) Sanity-check secrets file
grep -q '=' "$tmp_env" \
  || fail "Decrypted secrets file looks invalid (no KEY=VALUE pairs)"

# 8) Ensure no empty critical vars (extend as needed)
REQUIRED_VARS=(
  PLEX_API_KEY
  SONARR_API_KEY
  RADARR_API_KEY
  QBIT_USER
  QBIT_PASS
)

for var in "${REQUIRED_VARS[@]}"; do
  if ! grep -q "^${var}=.\+" "$tmp_env"; then
    fail "Required secret missing or empty: $var"
  fi
done

info "Secrets verified"

########################################
# RUN DOCKER COMPOSE
########################################
info "Running: docker compose $*"

docker compose \
  --env-file "$tmp_env" \
  "$@"
