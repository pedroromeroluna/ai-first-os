#!/usr/bin/env bash
# Usage: scripts/apply-capability-changes.sh <spec> [--root DIR] — applies the spec's '## Capability changes' onto capabilities/.
# Exit: 0 ok · 1 stopped (says capability, requirement and rule) · 2 misused. Format: capabilities/README.md.
exec python3 "$(dirname "$0")/capability_tools.py" apply "$@"
