# M0 runbook — freeze the baseline and make the workspace reproducible

Follow docs/DEV_PLAN.md Section 4 (M0) for the full goal and exit criteria.
This runbook orders the concrete commands. Steps marked **(manual)** need a
person at a browser or a decision only a person can make. Steps marked
**(script)** are automated by files in scripts/.

Run all of this on Environment A (the GPU host), unless a step says
otherwise.

## 1. Create the cloud GPU host **(manual)**

- Rent an RTX A6000 / L40 / L40S / RTX 6000 Ada class host, 48 GB VRAM,
  Linux, Docker + NVIDIA Container Toolkit installed.
- Do not rent an A100/H100: Isaac Sim needs RT cores, and NVIDIA lists
  those as unsupported for Isaac Sim rendering.
- Confirm `docker run --rm --gpus all nvidia/cuda:12.4.0-base-ubuntu22.04 nvidia-smi`
  works before continuing.

## 2. Create persistent directories **(script)**

```bash
./scripts/setup_persistent_dirs.sh /workspace/persist   # or your mount point
```

Creates `models/`, `datasets/`, `eval/`, `docker-cache/` under the given
path. Mount these into the Arena container in step 4 so models, datasets,
and eval output survive a container restart.

## 3. Clone and pin Arena **(script, then manual pin)**

```bash
./scripts/setup_arena.sh
```

First run clones `IsaacLab-Arena` as a git submodule at
`submodules/IsaacLab-Arena` and checks out the default branch. It prints
the current commit. **Do not stop here** — this is a floating checkout,
not a pin.

After step 4 passes (container launches, required test subset passes),
pin that commit:

```bash
./scripts/setup_arena.sh <commit_sha_printed_above>
git commit -m "Pin IsaacLab-Arena to <short_sha>"
```

## 4. Launch the supported environment **(manual)**

```bash
cd submodules/IsaacLab-Arena
./docker/run_docker.sh
```

Mount the persistent directories from step 2 (models/datasets/eval/cache)
per Arena's documented mount points. Inside the container, run the
provided test subset, including camera tests. Do not proceed until it
passes — a broken environment produces a broken dataset later.

## 5. Record the environment **(script, then manual fill-in)**

From the repo root, on the host (or inside the running container, with the
repo path available):

```bash
./scripts/record_environment.sh
```

Prints GPU model/driver, Docker version, Arena commit, Python version, and
`lerobot` version where it can detect them. Fields it cannot determine
(Isaac Sim/Lab version, container image hash, custom-metadata mechanism)
print as placeholders. Copy the output into `docs/environment.md`, then
fill in every remaining placeholder by hand. Do not consider M0 done while
`docs/environment.md` still has blank fields.

## 6. Pin the `lerobot` package **(manual decision + record)**

Per docs/DEV_PLAN.md Section 3: target `lerobot` v2.1 or the pinned
successor. This is an open design question — confirm the exact version
with the team before M3 starts, and confirm whether the pinned version
supports custom fields in `meta/episodes.jsonl`, or whether the
`episode_manifest.parquet` fallback is needed. Record both the version and
the answer in `docs/environment.md`. This step needs no GPU — it can be
done in Environment B, independent of steps 1-5.

## Required outputs checklist (docs/DEV_PLAN.md M0)

- [ ] A fresh shell can start the Arena container.
- [ ] Arena tests required for the selected workflow pass.
- [ ] Version manifest (`docs/environment.md`) is committed, including the
      pinned `lerobot` version.
- [ ] Persistent model/eval directories survive container restart.

**Exit criterion:** another machine of the same class can reproduce the
setup from the README without undocumented steps.
