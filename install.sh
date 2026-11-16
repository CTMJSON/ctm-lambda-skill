#!/usr/bin/env bash
# Install the ctm-lambda skill into your local agent runtime(s).
#
# Usage:
#   bash install.sh                 # install to every runtime it can find
#   bash install.sh --chatbox       # Chatbox only
#   bash install.sh --claude        # Claude Code only
#   bash install.sh --check         # show what is installed, change nothing
#   bash install.sh --dry-run       # print what would happen
#
# Safe to re-run. Existing installs are backed up before being replaced.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_NAME="ctm-lambda"
SRC="$SCRIPT_DIR/skill"

CHATBOX_DIR="$HOME/Library/Application Support/CTMChat/skills/$SKILL_NAME"
CLAUDE_DIR="$HOME/.claude/skills/$SKILL_NAME"

DO_CHATBOX=0
DO_CLAUDE=0
DRY_RUN=0
CHECK_ONLY=0

for arg in "$@"; do
  case "$arg" in
    --chatbox) DO_CHATBOX=1 ;;
    --claude)  DO_CLAUDE=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --check)   CHECK_ONLY=1 ;;
    -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $arg (try --help)" >&2; exit 1 ;;
  esac
done

# Default: install to every runtime present on this machine.
if [ "$DO_CHATBOX" -eq 0 ] && [ "$DO_CLAUDE" -eq 0 ]; then
  DO_CHATBOX=1
  DO_CLAUDE=1
fi

die() { echo "ERROR: $*" >&2; exit 1; }

[ -f "$SRC/SKILL.md" ] || die "Cannot find $SRC/SKILL.md — run this script from the cloned repo."
[ -f "$SRC/reference.md" ] || die "Cannot find $SRC/reference.md."

# Validate the frontmatter before installing, so a broken copy never lands.
validate() {
  local file="$1"
  head -1 "$file" | grep -qx -- '---' || return 1
  grep -qE '^name:[[:space:]]*[a-z0-9-]+[[:space:]]*$' "$file" || return 1
  grep -qE '^description:' "$file" || return 1
  local fm_chars
  fm_chars=$(awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{exit} f{print}' "$file" | wc -c | tr -d ' ')
  [ "$fm_chars" -lt 1024 ] || return 1
  return 0
}

if ! validate "$SRC/SKILL.md"; then
  die "skill/SKILL.md has invalid frontmatter (need name + description, under 1024 chars total)."
fi

install_to() {
  local label="$1" dest="$2"

  if [ "$CHECK_ONLY" -eq 1 ]; then
    if [ -f "$dest/SKILL.md" ]; then
      echo "  [installed]  $label: $dest"
    else
      echo "  [missing]    $label: $dest"
    fi
    return 0
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "  [dry-run]    would install $label -> $dest"
    return 0
  fi

  if [ -d "$dest" ]; then
    local backup="$dest.bak.$(date +%Y%m%d%H%M%S)"
    cp -R "$dest" "$backup"
    echo "  [backup]     $backup"
  fi

  mkdir -p "$dest"
  cp "$SRC/SKILL.md" "$SRC/reference.md" "$dest/"
  echo "  [installed]  $label: $dest"
}

echo "ctm-lambda skill"
echo "  source: $SRC"
echo

[ "$DO_CHATBOX" -eq 1 ] && install_to "Chatbox" "$CHATBOX_DIR"
[ "$DO_CLAUDE" -eq 1 ]  && install_to "Claude Code" "$CLAUDE_DIR"

echo
if [ "$CHECK_ONLY" -eq 1 ]; then
  echo "Check complete. Nothing was changed."
elif [ "$DRY_RUN" -eq 1 ]; then
  echo "Dry run complete. Nothing was changed."
else
  cat <<'EOF'
Done. Verify by asking the agent:

  "Use the ctm-lambda skill to write a routing lambda that sends
   calls tagged vip to queue QUE123 and everything else to QUE456."

If it answers with a complete script that calls context.done() on
every path including catch, the skill loaded correctly.

Note: Chatbox and Claude Code read skills at startup. If the skill
does not appear, restart the app / start a new session.
EOF
fi
