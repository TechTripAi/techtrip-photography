# incubator

Skills and recipes that are not ready to ship. Nothing in this folder is discovered by the
plugin manifests (Agent Plugins and Claude Code both read only `skills/`), so an incubator
skill never reaches an installed copy.

To try one locally, symlink it into `~/.claude/skills/<name>` for a session and remove the
link afterwards. To promote it: move the folder to `skills/<name>/`, add it to the README
"Skills included" list and to `photo-expert`'s menu, add a CHANGELOG line, run
`bash scripts/check.sh`.
