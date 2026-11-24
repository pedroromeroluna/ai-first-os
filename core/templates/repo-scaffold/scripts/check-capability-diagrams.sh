#!/usr/bin/env bash
# Usage: scripts/check-capability-diagrams.sh [--root DIR] — diagram form, and the general diagram names every capability; no network, no browser.
# Exit: 0 ok · 1 stopped (says capability, requirement and rule) · 2 misused. Format: capabilities/README.md.
exec python3 "$(dirname "$0")/capability_tools.py" check-diagrams "$@"
