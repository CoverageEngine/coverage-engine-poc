#!/usr/bin/env python
"""Validate one or more episodes against schemas/episode_schema.yaml. See DEV_PLAN.md M3."""

import argparse


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("dataset_path", help="Path to the LeRobotDataset directory")
    parser.add_argument("--episode-id", help="Validate a single episode only")
    parser.parse_args()
    raise NotImplementedError("Implement in M3: load schema, check required feature keys, "
                               "dimensions, monotonic timestamps, NaNs, episode length.")


if __name__ == "__main__":
    main()
