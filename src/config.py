"""Read shared project configuration."""

from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent


def load_params() -> dict:
    with open(ROOT / "params.yaml") as f:
        return yaml.safe_load(f)