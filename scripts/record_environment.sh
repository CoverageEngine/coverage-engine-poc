#!/usr/bin/env bash
# Gather host/container facts needed for docs/environment.md and print them
# in the order that file lists them. See docs/DEV_PLAN.md M0 step 5.
#
# Run this on Environment A, ideally right after ./docker/run_docker.sh has
# built and entered the Arena container, so the container/image hash and
# Isaac Sim / Isaac Lab versions are current. Values this script cannot
# determine on its own (Isaac Sim/Lab versions, lerobot custom-metadata
# support) print as "NOT FOUND" or "CONFIRM MANUALLY" placeholders —
# fill those in by hand in docs/environment.md.
#
# This script only reads the host; it does not write docs/environment.md
# for you, so a person reviews and commits the values.

set -uo pipefail

echo "## Environment A"
echo
if command -v nvidia-smi >/dev/null 2>&1; then
  echo "- GPU model: $(nvidia-smi --query-gpu=name --format=csv,noheader -i 0 2>/dev/null || echo 'NOT FOUND')"
  echo "- GPU driver version: $(nvidia-smi --query-gpu=driver_version --format=csv,noheader -i 0 2>/dev/null || echo 'NOT FOUND')"
else
  echo "- GPU model: NOT FOUND (nvidia-smi not on PATH)"
  echo "- GPU driver version: NOT FOUND (nvidia-smi not on PATH)"
fi

if command -v docker >/dev/null 2>&1; then
  echo "- Docker version: $(docker --version 2>/dev/null || echo 'NOT FOUND')"
else
  echo "- Docker version: NOT FOUND (docker not on PATH)"
fi

if [ -n "${ARENA_IMAGE:-}" ] && command -v docker >/dev/null 2>&1; then
  echo "- Container/image hash (${ARENA_IMAGE}): $(docker image inspect --format '{{.Id}}' "${ARENA_IMAGE}" 2>/dev/null || echo 'NOT FOUND')"
else
  echo "- Container/image hash: CONFIRM MANUALLY (set ARENA_IMAGE=<tag> and re-run, or 'docker image inspect <tag>')"
fi

if [ -d "submodules/IsaacLab-Arena/.git" ]; then
  echo "- Arena (IsaacLab-Arena) commit/release: $(git -C submodules/IsaacLab-Arena rev-parse HEAD)"
else
  echo "- Arena (IsaacLab-Arena) commit/release: NOT FOUND (run scripts/setup_arena.sh first)"
fi

echo "- Isaac Sim version: CONFIRM MANUALLY (check inside the Arena container)"
echo "- Isaac Lab version: CONFIRM MANUALLY (check inside the Arena container)"
echo
echo "## Environment B"
echo
echo "- Python version: $(python3 --version 2>/dev/null || echo 'NOT FOUND')"
if command -v pip >/dev/null 2>&1 && pip show lerobot >/dev/null 2>&1; then
  echo "- lerobot package version/commit: $(pip show lerobot 2>/dev/null | awk -F': ' '/^Version/{print $2}')"
else
  echo "- lerobot package version/commit: NOT FOUND (lerobot not installed here)"
fi
echo "- Custom episode-metadata mechanism confirmed: CONFIRM MANUALLY (see docs/DEV_PLAN.md Section 3)"
