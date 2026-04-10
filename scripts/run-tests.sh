#!/usr/bin/env bash
# scripts/run-tests.sh
#
# Automated integration test runner for the Ballerina GitHub trigger.
#
# What this script does:
#   1. Starts the Ballerina service on port 8090
#   2. Opens an ngrok HTTPS tunnel to expose it to the internet
#   3. Registers a GitHub webhook on the target repo pointing at the tunnel
#   4. Triggers a sequence of GitHub events via the GitHub API
#   5. Verifies that each event was received (by polling the service log)
#   6. Tears everything down regardless of outcome (via EXIT trap)
#
# Required environment variables:
#   GITHUB_REPO      — target repository, e.g. "myorg/myrepo"
#   WEBHOOK_SECRET   — arbitrary secret shared between GitHub and the service
#
# Optional:
#   LISTENER_PORT    — port the Ballerina service listens on (default: 8090)
#   EVENT_WAIT_SECS  — seconds to wait for each event to appear in logs (default: 20)
#
# Prerequisites:
#   bal, ngrok, gh (GitHub CLI), curl, jq

set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BAL_PKG="${REPO_ROOT}/asyncapi/github"
LOG_FILE="${REPO_ROOT}/service.log"
NGROK_LOG="${REPO_ROOT}/ngrok.log"
LISTENER_PORT="${LISTENER_PORT:-8090}"
EVENT_WAIT_SECS="${EVENT_WAIT_SECS:-20}"

SERVICE_PID=""
NGROK_PID=""
NGROK_URL=""
HOOK_ID=""

# ─── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
step()  { echo -e "\n${CYAN}━━━ $* ━━━${NC}"; }

# ─── Cleanup (runs on EXIT) ────────────────────────────────────────────────────
cleanup() {
    step "Teardown"
    if [[ -n "${HOOK_ID}" ]]; then
        if gh api "repos/${GITHUB_REPO}/hooks/${HOOK_ID}" --method DELETE &>/dev/null; then
            info "Webhook ${HOOK_ID} deleted."
        else
            warn "Could not delete webhook ${HOOK_ID} — remove it manually at https://github.com/${GITHUB_REPO}/settings/hooks"
        fi
    fi
    if [[ -n "${NGROK_PID}" ]] && kill -0 "${NGROK_PID}" 2>/dev/null; then
        kill "${NGROK_PID}" 2>/dev/null
        info "ngrok stopped."
    fi
    if [[ -n "${SERVICE_PID}" ]] && kill -0 "${SERVICE_PID}" 2>/dev/null; then
        kill "${SERVICE_PID}" 2>/dev/null
        info "Ballerina service stopped."
    fi
}
trap cleanup EXIT

# ─── Prerequisite check ───────────────────────────────────────────────────────
check_prereqs() {
    step "Checking prerequisites"
    local missing=()
    for cmd in bal ngrok gh curl jq; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing required tools: ${missing[*]}"
        exit 1
    fi
    [[ -n "${GITHUB_REPO:-}" ]]    || { error "GITHUB_REPO is not set (e.g. owner/repo)"; exit 1; }
    [[ -n "${WEBHOOK_SECRET:-}" ]] || { error "WEBHOOK_SECRET is not set"; exit 1; }
    info "All prerequisites satisfied."
}

# ─── Start Ballerina service ──────────────────────────────────────────────────
start_service() {
    step "Starting Ballerina service"

    # Write runtime config
    cat > "${BAL_PKG}/Config.toml" <<EOF
[listenerConfig]
webhookSecret = "${WEBHOOK_SECRET}"
EOF
    info "Config.toml written."

    # Launch in background, redirect all output to log
    rm -f "${LOG_FILE}"
    (cd "${BAL_PKG}" && bal run . 2>&1) > "${LOG_FILE}" &
    SERVICE_PID=$!
    info "Service starting (PID ${SERVICE_PID}), log → ${LOG_FILE}"

    # Wait until the TCP port is open (up to 60 s)
    local retries=60
    while ! nc -z localhost "${LISTENER_PORT}" 2>/dev/null; do
        if ! kill -0 "${SERVICE_PID}" 2>/dev/null; then
            error "Ballerina service exited prematurely. Last log lines:"
            tail -20 "${LOG_FILE}" >&2
            exit 1
        fi
        sleep 1; retries=$((retries - 1))
        if [[ $retries -le 0 ]]; then
            error "Service did not open port ${LISTENER_PORT} within 60 s."
            exit 1
        fi
    done
    info "Service is listening on port ${LISTENER_PORT}."
}

# ─── Start ngrok ──────────────────────────────────────────────────────────────
start_ngrok() {
    step "Starting ngrok"
    rm -f "${NGROK_LOG}"
    ngrok http "${LISTENER_PORT}" --log=stdout > "${NGROK_LOG}" 2>&1 &
    NGROK_PID=$!

    # Poll the ngrok API until a tunnel appears
    local retries=30
    while [[ $retries -gt 0 ]]; do
        NGROK_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null \
                    | jq -r '.tunnels[] | select(.proto=="https") | .public_url' 2>/dev/null \
                    || true)
        [[ -n "${NGROK_URL}" ]] && break
        sleep 1; retries=$((retries - 1))
    done

    if [[ -z "${NGROK_URL}" ]]; then
        error "Could not obtain ngrok HTTPS tunnel URL."
        exit 1
    fi
    info "Tunnel active: ${NGROK_URL}"
}

# ─── Register GitHub webhook ──────────────────────────────────────────────────
register_webhook() {
    step "Registering GitHub webhook"
    HOOK_ID=$(gh api "repos/${GITHUB_REPO}/hooks" \
        --method POST \
        --field name=web \
        --field active=true \
        --field "events[]=push" \
        --field "events[]=issues" \
        --field "events[]=issue_comment" \
        --field "events[]=pull_request" \
        --field "events[]=pull_request_review" \
        --field "events[]=pull_request_review_comment" \
        --field "events[]=release" \
        --field "events[]=label" \
        --field "events[]=milestone" \
        --field "config[url]=${NGROK_URL}/" \
        --field "config[content_type]=json" \
        --field "config[secret]=${WEBHOOK_SECRET}" \
        --jq '.id')
    info "Webhook registered — ID: ${HOOK_ID}"

    # Give GitHub a moment to send the initial ping event
    info "Waiting 5 s for webhook ping..."
    sleep 5
}

# ─── Assertion helper ─────────────────────────────────────────────────────────
PASS_COUNT=0
FAIL_COUNT=0

assert_log() {
    # assert_log <description> <grep-pattern> [timeout_secs]
    local desc="$1"
    local pattern="$2"
    local timeout="${3:-${EVENT_WAIT_SECS}}"
    local elapsed=0

    while [[ $elapsed -lt $timeout ]]; do
        grep -q "${pattern}" "${LOG_FILE}" 2>/dev/null && {
            echo -e "  ${GREEN}PASS${NC}  ${desc}"
            PASS_COUNT=$((PASS_COUNT + 1))
            return 0
        }
        sleep 1; elapsed=$((elapsed + 1))
    done
    echo -e "  ${RED}FAIL${NC}  ${desc}  (pattern: '${pattern}')"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

# ─── Run tests ────────────────────────────────────────────────────────────────
run_tests() {
    step "Triggering GitHub events"
    GITHUB_REPO="${GITHUB_REPO}" \
    WEBHOOK_SECRET="${WEBHOOK_SECRET}" \
        "${SCRIPT_DIR}/trigger-events.sh"

    step "Verifying event delivery"
    assert_log "Label created"            "Label created"
    assert_log "Milestone created"        "Milestone created"
    assert_log "Issue opened"             "Issue opened"
    assert_log "Issue labeled"            "Issue labeled"
    assert_log "Issue assigned"           "Issue assigned"
    assert_log "Issue comment created"    "Issue comment created"
    assert_log "Issue comment deleted"    "Issue comment deleted"
    assert_log "Issue closed"             "Issue closed"
    assert_log "Milestone closed"         "Milestone closed"
    assert_log "Release created"          "Release created"
    assert_log "Release published"        "Release published"
}

# ─── Report ───────────────────────────────────────────────────────────────────
report() {
    step "Results"
    local total=$((PASS_COUNT + FAIL_COUNT))
    echo -e "  Passed : ${GREEN}${PASS_COUNT}${NC} / ${total}"
    echo -e "  Failed : ${RED}${FAIL_COUNT}${NC} / ${total}"
    echo ""
    if [[ $FAIL_COUNT -gt 0 ]]; then
        error "Some tests failed. Review ${LOG_FILE} for details."
        exit 1
    fi
    info "All tests passed."
}

# ─── Entry point ──────────────────────────────────────────────────────────────
main() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  Ballerina GitHub Trigger — Automated Test Suite ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""

    check_prereqs
    start_service
    start_ngrok
    register_webhook
    run_tests
    report
}

main "$@"
