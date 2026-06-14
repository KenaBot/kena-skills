#!/usr/bin/env bash
# list-skills.sh — read skills from a skills directory
# Each skill is a subdirectory with a SKILL.md file.

# List skill names (one per line)
list_skill_names() {
  local skills_dir="$1"
  if [ ! -d "$skills_dir" ]; then
    return 1
  fi
  for dir in "$skills_dir"/*/; do
    [ -f "$dir/SKILL.md" ] && basename "$dir"
  done
}

# List skills as a formatted table: <name> | <description>
list_skills_table() {
  local skills_dir="$1"
  if [ ! -d "$skills_dir" ]; then
    echo "ERROR: skills directory not found: $skills_dir" >&2
    return 1
  fi

  python3 <<PYEOF
import os
import sys
import yaml

skills_dir = "$skills_dir"
if not os.path.isdir(skills_dir):
    print(f"ERROR: {skills_dir} is not a directory", file=sys.stderr)
    sys.exit(1)

found = []
for entry in sorted(os.listdir(skills_dir)):
    skill_md = os.path.join(skills_dir, entry, "SKILL.md")
    if not os.path.isfile(skill_md):
        continue
    try:
        with open(skill_md) as f:
            content = f.read()
        # Extract frontmatter
        parts = content.split("---", 2)
        if len(parts) < 3:
            continue
        data = yaml.safe_load(parts[1])
        name = data.get("name", entry)
        desc = (data.get("description") or "").strip().replace("\n", " ")
        # Truncate description
        if len(desc) > 100:
            desc = desc[:97] + "..."
        found.append((name, desc))
    except Exception as e:
        print(f"WARN: could not parse {skill_md}: {e}", file=sys.stderr)

if not found:
    print("No skills found.")
    sys.exit(0)

# Print table
print(f"{'NAME':<20} DESCRIPTION")
print("-" * 80)
for name, desc in found:
    print(f"{name:<20} {desc}")
PYEOF
}
