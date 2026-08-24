#!/usr/bin/env python
"""Report episode count, outcomes, lengths, and missing fields. See docs/DEV_PLAN.md M3/M5."""

import argparse


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("dataset_path", help="Path to the LeRobotDataset directory")
    parser.parse_args()
    raise NotImplementedError("Implement in M3: summarize episode count, success rate, "
                               "length distribution, missing/invalid fields.")


if __name__ == "__main__":
    main()
