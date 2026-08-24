"""Smoke test: the episode schema file exists and parses. See DEV_PLAN.md M3."""

from pathlib import Path

import yaml

SCHEMA_PATH = Path(__file__).resolve().parent.parent / "schemas" / "episode_schema.yaml"


def test_episode_schema_parses():
    schema = yaml.safe_load(SCHEMA_PATH.read_text())
    assert "schema_version" in schema
    assert "features" in schema
    assert "action" in schema["features"]
