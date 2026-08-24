# Coverage Engine — NVIDIA Robotics Stack POC

Reproducible pipeline: run a VLA-controlled pick-and-place task in NVIDIA Isaac, record rollouts as a LeRobotDataset, train a success-only Coverage model offline, and measure early-warning behavior before failures.

See [`DEV_PLAN.md`](./docs/DEV_PLAN.md) for the full execution plan, milestones, and data contract.

## Repository layout

```
configs/       Environment, rollout, and Coverage-model configs
robotics/      Environment-A code: launch, logging, sensors, outcome extraction
coverage/      Environment-B code: ingest, features, models, calibration, evaluation
schemas/       Dataset schema definitions (episode_schema.yaml)
scripts/       CLI entry points (validate, summarize, train, evaluate)
data/          LeRobotDataset rollout data (not committed — see .gitignore)
docs/          Environment manifests, reports
submodules/    IsaacLab-Arena (unmodified)
tests/         Unit and schema tests
```

## Status

M0 not started. See `docs/DEV_PLAN.md` Section 4 for milestone order and exit criteria.
