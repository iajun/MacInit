#!/usr/bin/env bash
# Scaffold a Manim math-explain video project.
# Usage: bash scaffold.sh <target_dir>

set -euo pipefail

TARGET="${1:-.}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATES="$ROOT/templates"

if [[ -e "$TARGET" && -n "$(ls -A "$TARGET" 2>/dev/null || true)" ]]; then
  echo "Target exists and is not empty: $TARGET" >&2
  echo "Choose an empty directory." >&2
  exit 1
fi

mkdir -p "$TARGET"
cp -R "$TEMPLATES/"* "$TARGET/"

# normalize dirs
mkdir -p "$TARGET/scenes/shared" "$TARGET/narrations" \
  "$TARGET/exports/landscape" "$TARGET/exports/portrait" "$TARGET/assets"

# package marker for imports
touch "$TARGET/scenes/__init__.py"
touch "$TARGET/scenes/shared/__init__.py"

cat > "$TARGET/README.md" << 'EOF'
# Manim Math Explain Project

## Setup

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Preview

```bash
# landscape 16:9
manim -pql scenes/01_example.py ExampleHook

# portrait 9:16
MANIM_FORMAT=portrait manim -pql scenes/01_example.py ExampleHook -r 1080,1920
```

Delete `scenes/01_example.py` after Scene 01 real content exists.

Workflow: follow the manim-math-explain skill — checkpoints before each phase.
EOF

echo "Scaffolded → $TARGET"
echo "Next: write/confirm script + outline, then replace 01_example with Scene 01."
