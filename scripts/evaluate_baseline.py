#!/usr/bin/env python
"""Score held-out episodes and report recall, false-alarm rate, lead time.

See docs/DEV_PLAN.md M6/M7/M8.
"""

import argparse


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model", required=True, help="Path to a saved model + normalizer + "
                         "threshold")
    parser.add_argument("--dataset-path", required=True,
                         help="Path to the LeRobotDataset directory")
    parser.parse_args()
    raise NotImplementedError("Implement in M6: score full episodes, compute recall/precision/"
                               "false-alarm/lead-time/AUROC per docs/DEV_PLAN.md Section 5.")


if __name__ == "__main__":
    main()
