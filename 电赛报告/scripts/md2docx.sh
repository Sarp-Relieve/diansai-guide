#!/usr/bin/env bash
# 电赛报告 md → docx 快捷封装
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec python3 "$SCRIPT_DIR/md_to_docx.py" "$@"
