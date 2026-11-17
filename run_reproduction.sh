#!/usr/bin/env bash
set -euo pipefail
repo_root="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
export NHANES_DATA_ROOT="${NHANES_DATA_ROOT:-$repo_root/input_data}"
python3 "$repo_root/scripts/fetch_data.py"
Rscript "$repo_root/analysis/scripts/main_analysis.R"
Rscript "$repo_root/analysis/review/independent_recalc.R"
python3 "$repo_root/scripts/assemble_saved_sensitivities.py" --output-dir "$repo_root/analysis/outputs"
python3 "$repo_root/scripts/compare_outputs.py"
