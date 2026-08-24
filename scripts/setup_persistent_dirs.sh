#!/usr/bin/env bash
# Create the persistent directory layout for Environment A (robotics data
# generation host) before building the Arena container. See docs/DEV_PLAN.md
# M0 step 2. Run this once per host, before ./setup_arena.sh.
#
# Usage: ./setup_persistent_dirs.sh [base_path]
# base_path defaults to $PERSIST_ROOT, or ./persist if that is unset.

set -euo pipefail

BASE_PATH="${1:-${PERSIST_ROOT:-./persist}}"

DIRS=(
  "models"        # GR00T weights, HF hub cache
  "datasets"      # LeRobotDataset output (data/<dataset_name>/...)
  "eval"          # evaluation logs and reports
  "docker-cache"  # Isaac Sim / Omniverse cache, so it survives container restart
)

for dir in "${DIRS[@]}"; do
  mkdir -p "${BASE_PATH}/${dir}"
done

echo "Persistent directories ready under: ${BASE_PATH}"
printf '  %s\n' "${DIRS[@]/#/${BASE_PATH}/}"
echo
echo "Next: mount these into the Arena container (see docs/runbooks/m0_setup.md),"
echo "then run ./setup_arena.sh."
