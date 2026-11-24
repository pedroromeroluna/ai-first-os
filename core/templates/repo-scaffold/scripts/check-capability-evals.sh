#!/usr/bin/env bash
# Usage: scripts/check-capability-evals.sh <suite output> [--root DIR] — every requirement names Evals: ids and each has a PASS line.
# Exit: 0 ok · 1 stopped (says capability, requirement and rule) · 2 misused. Format: capabilities/README.md.
exec python3 "$(dirname "$0")/capability_tools.py" check-evals "$@"
