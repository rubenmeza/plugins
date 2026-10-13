#!/usr/bin/env bash
# Install pstack for Claude Code and Codex by symlinking this checkout.
#   skills/<name>  -> ~/.agents/skills/<name>   (Codex reads this directly)
#                  -> ~/.claude/skills/<name>   (symlink to the ~/.agents copy)
#   agents/<name>.md -> ~/.claude/agents/<name>.md
# Re-run after `git pull` to pick up new skills. Pass --uninstall to remove
# only the links that point into this checkout.
set -euo pipefail

src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
agents_skills="$HOME/.agents/skills"
claude_skills="$HOME/.claude/skills"
claude_agents="$HOME/.claude/agents"
mode="${1:-install}"

owned() { [ -L "$1" ] && case "$(readlink -f "$1")" in "$src"/*) return 0 ;; esac; return 1; }

link() {
  local target="$1" dest="$2"
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    if owned "$dest" || [ "$(readlink "$dest")" = "$target" ]; then
      ln -sfn "$target" "$dest"
    else
      echo "skip $dest (exists, not from pstack)" >&2
      return 0
    fi
  else
    ln -s "$target" "$dest"
  fi
}

if [ "$mode" = "--uninstall" ]; then
  for d in "$agents_skills" "$claude_skills" "$claude_agents"; do
    [ -d "$d" ] || continue
    for f in "$d"/*; do
      if owned "$f"; then rm "$f" && echo "removed $f"; fi
    done
  done
  exit 0
fi

mkdir -p "$agents_skills" "$claude_skills" "$claude_agents"

count=0
for dir in "$src"/skills/*/; do
  name="$(basename "$dir")"
  link "$src/skills/$name" "$agents_skills/$name"
  if owned "$agents_skills/$name"; then
    link "$agents_skills/$name" "$claude_skills/$name"
    count=$((count + 1))
  fi
done

for f in "$src"/agents/*.md; do
  link "$f" "$claude_agents/$(basename "$f")"
done

echo "linked $count skills and $(ls "$src"/agents/*.md | wc -l) agents from $src"
echo "next: run /setup-pstack in Claude Code or Codex to pick models"
