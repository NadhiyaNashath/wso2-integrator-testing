#!/usr/bin/env bash
# scripts/run-tests.sh
#
# Unified integration test runner for the Ballerina GitHub trigger.
#
# Modes:
#   Central (default) — tests against the published ballerinax/trigger.github
#                       package from Ballerina Central; no cloning required.
#   Local build       — clones ballerina-platform/asyncapi-triggers, builds the
#                       github trigger package, publishes it to the Ballerina local
#                       repository, and tests against that build instead.
#                       Triggered by passing --ref or --pr.
#
# In both modes the script:
#   1. Starts the Ballerina service on port 8090
#   2. Opens an ngrok HTTPS tunnel to expose it to the internet
#   3. Registers a GitHub webhook on the target repo pointing at the tunnel
#   4. Fires a sequence of GitHub events via the GitHub API
#   5. Verifies each event appears in the service log
#   6. Tears everything down on exit (via EXIT trap)
#
# Usage:
#   GITHUB_REPO=owner/repo WEBHOOK_SECRET=secret scripts/run-tests.sh [options]
#
# Options:
#   --ref <branch|tag>   Local build mode: clone and test a branch or tag
#   --pr  <number>       Local build mode: clone and test a pull request by number
#                        (works for fork PRs too; takes precedence over --ref)
#   -h, --help           Show this help message and exit
#
# Required environment variables:
#   GITHUB_REPO          Target GitHub repository, e.g. "myorg/myrepo"
#   WEBHOOK_SECRET       Secret shared with the Ballerina service for HMAC-SHA256
#                        webhook signature validation
#
# Optional environment variables:
#   LISTENER_PORT        Port the Ballerina service listens on (default: 8090)
#   EVENT_WAIT_SECS      Seconds to wait for each event to appear in the service
#                        log before marking the assertion failed (default: 20)
#
# Prerequisites (Central mode):
#   bal, ngrok, gh (GitHub CLI), curl, jq, nc
# Additional prerequisites (local build mode):
#   git, python3

set -euo pipefail

# ─── Paths & defaults ─────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BAL_PKG="${REPO_ROOT}/asyncapi/github"
BAL_TOML="${BAL_PKG}/Ballerina.toml"
BAL_TOML_BACKUP="${BAL_TOML}.run-tests.bak"
LOG_FILE="${REPO_ROOT}/service.log"
NGROK_LOG="${REPO_ROOT}/ngrok.log"

TRIGGER_REPO="https://github.com/ballerina-platform/asyncapi-triggers.git"
CLONE_DIR="/tmp/asyncapi-triggers-$$"   # $$ keeps parallel runs isolated

LISTENER_PORT="${LISTENER_PORT:-8090}"
EVENT_WAIT_SECS="${EVENT_WAIT_SECS:-20}"

SERVICE_PID=""
NGROK_PID=""
NGROK_URL=""
HOOK_ID=""
PR_NUMBER=""
REF=""

# ─── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
step()  { echo -e "\n${CYAN}━━━ $* ━━━${NC}"; }

# ─── Help ─────────────────────────────────────────────────────────────────────
usage() {
    cat <<EOF
Usage: GITHUB_REPO=owner/repo WEBHOOK_SECRET=secret $(basename "$0") [options]

Unified integration test runner for the Ballerina GitHub trigger.

Runs in one of two modes depending on the options provided:

  Central mode (default, no --ref/--pr)
    Tests against the published ballerinax/trigger.github package from
    Ballerina Central. No cloning or local build required.

  Local build mode (--ref or --pr)
    Clones ballerina-platform/asyncapi-triggers, builds the github trigger
    package locally, publishes it to the Ballerina local repository, and
    runs the tests against that build instead of the Central version.

Options:
  --ref <branch|tag>    Local build mode: branch or tag to test
  --pr  <number>        Local build mode: pull request number to test
                        (works for fork PRs; takes precedence over --ref)
  -h, --help            Show this help message and exit

Required environment variables:
  GITHUB_REPO           Target GitHub repository, e.g. "myorg/myrepo"
  WEBHOOK_SECRET        Secret shared with the Ballerina service for
                        HMAC-SHA256 webhook signature validation

Optional environment variables:
  LISTENER_PORT         Port the Ballerina service listens on (default: 8090)
  EVENT_WAIT_SECS       Seconds to wait for each event assertion (default: 20)

Prerequisites (Central mode):
  bal, ngrok, gh (GitHub CLI), curl, jq, nc

Additional prerequisites (local build mode):
  git, python3

Examples:
  # Central mode
  GITHUB_REPO=myorg/myrepo WEBHOOK_SECRET=secret \\
    $(basename "$0")

  # Local build — test a branch
  GITHUB_REPO=myorg/myrepo WEBHOOK_SECRET=secret \\
    $(basename "$0") --ref feature/my-fix

  # Local build — test a pull request
  GITHUB_REPO=myorg/myrepo WEBHOOK_SECRET=secret \\
    $(basename "$0") --pr 42
EOF
    exit 0
}

# ─── Argument parsing ─────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --pr)      PR_NUMBER="$2"; shift 2 ;;
        --ref)     REF="$2";       shift 2 ;;
        -h|--help) usage ;;
        *) error "Unknown option: $1"; echo "Run '$(basename "$0") --help' for usage." >&2; exit 1 ;;
    esac
done

# Helper: true when running in local-build mode
is_local_mode() { [[ -n "${PR_NUMBER}" || -n "${REF}" ]]; }

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
        # Kill the entire process group (setsid makes SERVICE_PID the PGID).
        # This ensures the JVM child process doesn't become an orphan on port 8090.
        kill -TERM -- "-${SERVICE_PID}" 2>/dev/null || kill "${SERVICE_PID}" 2>/dev/null || true
        local waited=0
        while kill -0 "${SERVICE_PID}" 2>/dev/null && [[ $waited -lt 5 ]]; do
            sleep 1; waited=$((waited + 1))
        done
        # Force-kill if still alive after 5 s
        if kill -0 "${SERVICE_PID}" 2>/dev/null; then
            kill -KILL -- "-${SERVICE_PID}" 2>/dev/null || kill -9 "${SERVICE_PID}" 2>/dev/null || true
        fi
        info "Ballerina service stopped."
    fi
    if is_local_mode; then
        if [[ -f "${BAL_TOML_BACKUP}" ]]; then
            mv "${BAL_TOML_BACKUP}" "${BAL_TOML}"
            info "Ballerina.toml restored."
        fi
        if [[ -d "${CLONE_DIR}" ]]; then
            rm -rf "${CLONE_DIR}"
            info "Removed temporary clone ${CLONE_DIR}."
        fi
    fi
}
trap cleanup EXIT

# ─── Prerequisite check ───────────────────────────────────────────────────────
check_prereqs() {
    step "Checking prerequisites"
    local tools=(bal ngrok gh curl jq nc)
    is_local_mode && tools+=(git python3)

    local missing=()
    for cmd in "${tools[@]}"; do
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

# ─── Local build: clone ───────────────────────────────────────────────────────
clone_repo() {
    if [[ -n "${PR_NUMBER}" ]]; then
        step "Cloning asyncapi-triggers (PR #${PR_NUMBER})"
        git clone --depth 1 "${TRIGGER_REPO}" "${CLONE_DIR}"
        git -C "${CLONE_DIR}" fetch --depth 1 origin "pull/${PR_NUMBER}/head"
        git -C "${CLONE_DIR}" checkout FETCH_HEAD
        info "Checked out PR #${PR_NUMBER} ($(git -C "${CLONE_DIR}" rev-parse --short HEAD))"
    else
        step "Cloning asyncapi-triggers (ref: ${REF})"
        git clone --depth 1 --branch "${REF}" "${TRIGGER_REPO}" "${CLONE_DIR}"
        info "Cloned ref '${REF}' ($(git -C "${CLONE_DIR}" rev-parse --short HEAD))"
    fi
}

# ─── Local build: publish to Ballerina local repository ───────────────────────
publish_local() {
    step "Building and publishing trigger.github to local repository"
    local trigger_pkg="${CLONE_DIR}/asyncapi/github"
    local local_version
    local_version=$(grep '^version' "${trigger_pkg}/Ballerina.toml" | head -1 \
                    | sed 's/version *= *"\([^"]*\)".*/\1/')
    info "Package version: ${local_version}"
    (cd "${trigger_pkg}" && bal pack)
    (cd "${trigger_pkg}" && bal push --repository local)
    info "ballerinax/trigger.github:${local_version} published to local repository."
}

# ─── Local build: patch Ballerina.toml ────────────────────────────────────────
patch_toml() {
    step "Patching asyncapi/github/Ballerina.toml"
    local trigger_pkg="${CLONE_DIR}/asyncapi/github"
    local local_version
    local_version=$(grep '^version' "${trigger_pkg}/Ballerina.toml" | head -1 \
                    | sed 's/version *= *"\([^"]*\)".*/\1/')

    cp "${BAL_TOML}" "${BAL_TOML_BACKUP}"

    # Remove any existing trigger.github [[dependency]] block then append a
    # fresh one pointing at the local repository. Handles the block being
    # absent, present, or duplicated equally well.
    python3 - "${BAL_TOML}" "${local_version}" <<'PYEOF'
import sys

path, new_version = sys.argv[1], sys.argv[2]

with open(path) as f:
    lines = f.readlines()

result = []
i = 0
while i < len(lines):
    if lines[i].rstrip() == '[[dependency]]':
        block = [lines[i]]
        j = i + 1
        while j < len(lines) and not lines[j].rstrip().startswith('[['):
            block.append(lines[j])
            j += 1
        if not any('trigger.github' in l for l in block):
            result.extend(block)    # keep unrelated dependency blocks
        i = j
    else:
        result.append(lines[i])
        i += 1

while result and result[-1].strip() == '':
    result.pop()

result += [
    '\n',
    '[[dependency]]\n',
    'org = "ballerinax"\n',
    'name = "trigger.github"\n',
    f'version = "{new_version}"\n',
    'repository = "local"\n',
]

with open(path, 'w') as f:
    f.writelines(result)
PYEOF

    info "Ballerina.toml patched (version=${local_version}, repository=local):"
    grep -A5 'trigger\.github' "${BAL_TOML}"
}

# ─── Start Ballerina service ──────────────────────────────────────────────────
start_service() {
    step "Starting Ballerina service"
    cat > "${BAL_PKG}/Config.toml" <<EOF
[listenerConfig]
webhookSecret = "${WEBHOOK_SECRET}"
EOF
    info "Config.toml written."

    rm -f "${LOG_FILE}"
    # Use setsid so the service and all its children (JVM, etc.) share a new
    # process group.  This lets cleanup() kill the whole group reliably.
    setsid bash -c "cd '${BAL_PKG}' && bal run . 2>&1" > "${LOG_FILE}" &
    SERVICE_PID=$!
    info "Service starting (PID ${SERVICE_PID}), log → ${LOG_FILE}"

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
    info "Waiting 5 s for webhook ping..."
    sleep 5
}

# ─── Assertions ───────────────────────────────────────────────────────────────
PASS_COUNT=0
FAIL_COUNT=0

assert_log() {
    local desc="$1" pattern="$2" timeout="${3:-${EVENT_WAIT_SECS}}" elapsed=0
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

# ─── Trigger events & verify ──────────────────────────────────────────────────
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

    if is_local_mode; then
        [[ -n "${PR_NUMBER}" ]] \
            && info "Mode: local build  (PR #${PR_NUMBER})" \
            || info "Mode: local build  (ref: ${REF})"
    else
        info "Mode: Central package (ballerinax/trigger.github)"
    fi

    check_prereqs

    if is_local_mode; then
        clone_repo
        publish_local
        patch_toml
    fi

    start_service
    start_ngrok
    register_webhook
    run_tests
    report
}

main "$@"
