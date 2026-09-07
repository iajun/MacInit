---
name: shell-init-skills
description: Manage shared AI Agent Skills on this Mac via shell-init; use when adding, linking, or troubleshooting skills for Cursor, Claude Code, Codex, and other detected agents.
---

# shell-init skills

Personal skills live in one place. Sync **auto-detects** installed AI tools and symlinks each skill:

```text
shell-init/packages/skills/<skill-name>/SKILL.md
  → ~/.cursor/skills/<skill-name>      # if Cursor present
  → ~/.claude/skills/<skill-name>      # if Claude present
  → ~/.agents/skills/<skill-name>      # shared standard
  → …                                  # see targets.conf
```

## Add a skill

1. Create `packages/skills/<name>/SKILL.md` (YAML frontmatter: `name`, `description`).
2. Run `./setup.sh --steps=skills` (or include `skills` in `config` / `bootstrap`).
3. Restart or reload the agent so it rescans skills.

## Targets

Catalog + probe paths: `packages/skills/targets.conf`.

```bash
./setup.sh --steps=skills                      # auto-detect
./setup.sh --steps=skills --skills-targets=cursor,claude
./setup.sh --steps=skills --skills-targets=all
```

## Notes

- Only directories containing `SKILL.md` are linked.
- Existing correct symlinks are left alone (idempotent); `--force` re-links.
- Destructive replace backs up under `~/.cache/shell-init/backups/`.
