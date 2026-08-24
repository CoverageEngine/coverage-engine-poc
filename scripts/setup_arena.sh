#!/usr/bin/env bash
# Add or update the IsaacLab-Arena git submodule and, once a commit is
# chosen, pin it. See docs/DEV_PLAN.md M0 step 3.
#
# Run this from the repository root, on Environment A (or anywhere with
# network access to the Arena repo) — it is not part of the Coverage
# package and needs no GPU to run this step itself.
#
# Usage:
#   ./scripts/setup_arena.sh              # first run: clone default branch, report HEAD commit
#   ./scripts/setup_arena.sh <commit_or_tag>  # pin: check out that ref and stage it
#
# ARENA_REPO_URL can override the default repo URL (e.g. to use https instead
# of ssh).

set -euo pipefail

REPO_URL="${ARENA_REPO_URL:-git@github.com:isaac-sim/IsaacLab-Arena.git}"
SUBMODULE_PATH="submodules/IsaacLab-Arena"
PIN_REF="${1:-}"

if [ ! -d "${SUBMODULE_PATH}/.git" ]; then
  echo "Adding Arena as a git submodule at ${SUBMODULE_PATH} ..."
  git submodule add "${REPO_URL}" "${SUBMODULE_PATH}"
fi

git submodule update --init --recursive "${SUBMODULE_PATH}"

if [ -n "${PIN_REF}" ]; then
  echo "Pinning Arena to ${PIN_REF} ..."
  git -C "${SUBMODULE_PATH}" fetch --tags origin
  git -C "${SUBMODULE_PATH}" checkout "${PIN_REF}"
  git submodule update --init --recursive "${SUBMODULE_PATH}"
  git add "${SUBMODULE_PATH}" .gitmodules
  echo
  echo "Staged. Commit this to record the pin, e.g.:"
  echo "  git commit -m \"Pin IsaacLab-Arena to ${PIN_REF}\""
else
  CURRENT_COMMIT="$(git -C "${SUBMODULE_PATH}" rev-parse HEAD)"
  echo
  echo "Arena checked out at commit: ${CURRENT_COMMIT}"
  echo "This is a floating checkout of the default branch — not yet pinned."
  echo "Per docs/DEV_PLAN.md M0: do not track a floating main branch after the"
  echo "first successful setup. Once ./docker/run_docker.sh and the required"
  echo "test subset (including camera tests) pass on this commit, pin it:"
  echo "  ./scripts/setup_arena.sh ${CURRENT_COMMIT}"
fi
