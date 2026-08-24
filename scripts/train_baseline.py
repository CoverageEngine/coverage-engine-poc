#!/usr/bin/env python
"""Train the success-only Coverage baseline (future-state prediction error).

See DEV_PLAN.md M6/M7.
"""

import argparse


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", required=True, help="Path to a coverage training config "
                         "(configs/coverage/*.yaml) selecting feature keys, e.g. with/without "
                         "observation.contact.* for the M7 ablation")
    parser.parse_args()
    raise NotImplementedError("Implement in M6: build feature vectors from selected LeRobot "
                               "feature keys, normalize on training-success split, train "
                               "predictor, calibrate threshold.")


if __name__ == "__main__":
    main()
