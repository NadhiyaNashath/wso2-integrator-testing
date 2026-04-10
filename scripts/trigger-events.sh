#!/usr/bin/env bash
# scripts/trigger-events.sh
#
# Drives a sequence of GitHub API calls to fire every major webhook event
# type that the Ballerina GitHub trigger handles.
#
# Events covered:
#   label.*          — LabelService   (created, deleted)
#   milestone.*      — MilestoneService (created, closed)
#   issues.*         — IssuesService  (opened, labeled, assigned, closed)
#   issue_comment.*  — IssueCommentService (created, deleted)
#   release.*        — ReleaseService (created, published)
#
# Note: push and pull_request events require real branch/commit operations
# and are not included here. Test those by pushing to the repo while the
# service is running.
#
# Required environment variables:
#   GITHUB_REPO   — target repository, e.g. "myorg/myrepo"

set -euo pipefail

[[ -n "${GITHUB_REPO:-}" ]] || { echo "ERROR: GITHUB_REPO is not set" >&2; exit 1; }

CYAN='\033[0;36m'; GREEN='\033[0;32m'; NC='\033[0m'
step() { echo -e "\n${CYAN}  ▶ $*${NC}"; }
ok()   { echo -e "    ${GREEN}✓${NC}  $*"; }

# Unique suffix to avoid name collisions on repeated runs
SUFFIX="$(date +%s)"

# ─── Label ────────────────────────────────────────────────────────────────────
LABEL_NAME="auto-test-${SUFFIX}"

step "Creating label '${LABEL_NAME}'..."
gh api "repos/${GITHUB_REPO}/labels" \
    --method POST \
    --field name="${LABEL_NAME}" \
    --field color="c5def5" \
    --field description="Created by Ballerina trigger automated test" \
    --silent
ok "label.created"

sleep 2

# ─── Milestone ────────────────────────────────────────────────────────────────
MILESTONE_TITLE="Auto-test Milestone ${SUFFIX}"

step "Creating milestone '${MILESTONE_TITLE}'..."
MILESTONE_NUMBER=$(gh api "repos/${GITHUB_REPO}/milestones" \
    --method POST \
    --field title="${MILESTONE_TITLE}" \
    --field description="Created by Ballerina trigger automated test" \
    --jq '.number')
ok "milestone.created  (#${MILESTONE_NUMBER})"

sleep 2

# ─── Issue ────────────────────────────────────────────────────────────────────
ISSUE_TITLE="Auto-test Issue ${SUFFIX}"

step "Opening issue '${ISSUE_TITLE}'..."
ISSUE_NUMBER=$(gh api "repos/${GITHUB_REPO}/issues" \
    --method POST \
    --field title="${ISSUE_TITLE}" \
    --field body="Issue created by the Ballerina GitHub trigger automated test suite." \
    --jq '.number')
ok "issues.opened  (#${ISSUE_NUMBER})"

sleep 2

step "Labeling issue #${ISSUE_NUMBER} with '${LABEL_NAME}'..."
gh api "repos/${GITHUB_REPO}/issues/${ISSUE_NUMBER}/labels" \
    --method POST \
    --field "labels[]=${LABEL_NAME}" \
    --silent
ok "issues.labeled"

sleep 2

step "Assigning issue #${ISSUE_NUMBER} to repo owner..."
REPO_OWNER="${GITHUB_REPO%%/*}"
gh api "repos/${GITHUB_REPO}/issues/${ISSUE_NUMBER}" \
    --method PATCH \
    --field "assignees[]=${REPO_OWNER}" \
    --silent
ok "issues.assigned  (→ ${REPO_OWNER})"

sleep 2

# ─── Issue Comment ────────────────────────────────────────────────────────────
step "Adding comment to issue #${ISSUE_NUMBER}..."
COMMENT_ID=$(gh api "repos/${GITHUB_REPO}/issues/${ISSUE_NUMBER}/comments" \
    --method POST \
    --field body="Automated test comment — verifying IssueCommentService.onCreated." \
    --jq '.id')
ok "issue_comment.created  (id: ${COMMENT_ID})"

sleep 2

step "Deleting comment ${COMMENT_ID}..."
gh api "repos/${GITHUB_REPO}/issues/comments/${COMMENT_ID}" \
    --method DELETE \
    --silent
ok "issue_comment.deleted"

sleep 2

# ─── Close issue ──────────────────────────────────────────────────────────────
step "Closing issue #${ISSUE_NUMBER}..."
gh api "repos/${GITHUB_REPO}/issues/${ISSUE_NUMBER}" \
    --method PATCH \
    --field state=closed \
    --silent
ok "issues.closed"

sleep 2

# ─── Release ─────────────────────────────────────────────────────────────────
TAG_NAME="auto-test-${SUFFIX}"

step "Creating and publishing release '${TAG_NAME}'..."
gh api "repos/${GITHUB_REPO}/releases" \
    --method POST \
    --field tag_name="${TAG_NAME}" \
    --field name="Auto-test Release ${SUFFIX}" \
    --field body="Release created by Ballerina trigger automated test suite." \
    --field draft=false \
    --field prerelease=false \
    --silent
ok "release.created + release.published"

sleep 2

# ─── Milestone close ──────────────────────────────────────────────────────────
step "Closing milestone #${MILESTONE_NUMBER}..."
gh api "repos/${GITHUB_REPO}/milestones/${MILESTONE_NUMBER}" \
    --method PATCH \
    --field state=closed \
    --silent
ok "milestone.closed"

echo ""
echo "All events triggered successfully."
