#!/usr/bin/env bash
# scripts/cleanup.sh
#
# Standalone cleanup script. Removes all webhooks on the target repo that
# were left behind by a previous test run (e.g. if run-tests.sh was killed
# before its EXIT trap could fire).
#
# Required environment variables:
#   GITHUB_REPO   — target repository, e.g. "myorg/myrepo"

set -euo pipefail

[[ -n "${GITHUB_REPO:-}" ]] || { echo "ERROR: GITHUB_REPO is not set (e.g. owner/repo)" >&2; exit 1; }

echo "Fetching webhooks for ${GITHUB_REPO}..."
HOOK_IDS=$(gh api "repos/${GITHUB_REPO}/hooks" --jq '.[].id' 2>/dev/null || true)

if [[ -z "${HOOK_IDS}" ]]; then
    echo "No webhooks found on ${GITHUB_REPO}."
    exit 0
fi

for id in ${HOOK_IDS}; do
    if gh api "repos/${GITHUB_REPO}/hooks/${id}" --method DELETE --silent 2>/dev/null; then
        echo "  Deleted webhook ${id}."
    else
        echo "  WARNING: could not delete webhook ${id}." >&2
    fi
done

echo "Done."
