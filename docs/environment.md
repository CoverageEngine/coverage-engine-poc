# Environment manifest

Fill this in during M0. Do not treat the stack as reproducible until every field below is recorded.

## Environment A — robotics data generation

- GPU model:
- GPU driver version:
- Docker version:
- Container/image hash:
- Arena (IsaacLab-Arena) commit/release:
- Isaac Sim version:
- Isaac Lab version:

## Environment B — Coverage development

- Python version:
- `lerobot` package version/commit:
- Custom episode-metadata mechanism confirmed: `meta/episodes.jsonl` custom fields / `episode_manifest.parquet` fallback (delete the one that doesn't apply)

## Dataset schema

- `schema_version` (schemas/episode_schema.yaml):
- LeRobot `codebase_version` (meta/info.json):
