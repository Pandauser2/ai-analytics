#!/usr/bin/env bash
# Run the North Star app with the same `python3` used for `pip install` (avoids
# "missing google-cloud-bigquery" when the `streamlit` CLI points at another Python).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
python3 -m pip install -r requirements.txt
exec python3 -m streamlit run streamlit_north_star_app.py
