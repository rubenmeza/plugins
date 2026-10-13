# Harness adapter

pstack's skills are written against Cursor's tools. This file maps each Cursor concept to Claude Code and Codex. Any skill that names a Cursor tool, path, or model slug points here. Read it once per session, then translate as you go. In Cursor, ignore this file.

## Which harness am I in

- **Cursor.** You have a `Task` tool with `subagent_type`, `readonly`, and `environment`.
- **Claude Code.** You have an `Agent` tool (older builds call it `Task`) with `subagent_type`, `model`, `run_in_background`, and `isolation`.
- **Codex.** You have `spawn_agent`, `wait_agent`, `send_input`, and `close_agent`.

## Model configuration

Cursor reads `~/.cursor/rules/pstack-models.mdc` as an always-applied rule. Claude Code and Codex share `~/.agents/pstack-models.md` instead, and nothing loads it for you. Before the first spawn in any skill that names a role line, read that file if it exists. "The `pstack-models.mdc` rule" in any skill means this file. `/setup-pstack` writes it.

A role value takes one of these forms.

| Value | Meaning |
|---|---|
| `inherit-parent`, `auto` | Run on the parent model. Omit `model`. |
| A native model | Claude Code: `opus`, `sonnet`, `haiku`, `fable`, or a full `claude-*` id. Codex: a slug from `~/.codex/models_cache.json`, such as `gpt-5.6-sol`. |
| `<model>@<effort>` | A native model at a reasoning effort, such as `gpt-5.6-sol@xhigh`. Codex passes the effort as `reasoning_effort`. Claude Code subagents cannot set effort per spawn, so drop the suffix there. |
| `codex` or `codex:<model>[@<effort>]` | Cross-family runner from Claude Code. Run it through the Codex CLI (see Cross-family runs). Bare `codex` uses Codex's configured default model. |
| `claude` or `claude:<model>[@<effort>]` | Cross-family runner from Codex. Run it through the Claude CLI. Bare `claude` uses `opus`. |

### Default translation

When no config line exists, a skill's Cursor default translates like this.

| Cursor default | Claude Code | Codex |
|---|---|---|
| `claude-opus-5-5-xhigh` (judgment, prose, hardest tasks) | `opus` | `inherit-parent` |
| `grok-4.7-xhigh-fast` (code delegates, explorers, investigators, workers) | `sonnet` | `inherit-parent` |
| The second member of a two-family panel (arena, architect, interrogate, cross-judge) | `codex` | `claude` |

Panels exist for model diversity. Keep the cross-family member when its CLI is installed (`command -v codex` or `command -v claude`). If it is not installed, run that panel member on the parent model and say the panel lost its second family.

When a skill says "if the Task tool rejects a slug", read it as "if the spawn or the CLI call fails with an unknown model".

## Tools and parameters

| Cursor | Claude Code | Codex |
|---|---|---|
| `Task` call | `Agent` call | `spawn_agent`, then `wait_agent` for the result |
| Several `Task` calls in one message | Several `Agent` calls in one message | Several `spawn_agent` calls, then one `wait_agent` over all ids |
| `subagent_type: generalPurpose` | `subagent_type: "general-purpose"` | Omit `agent_type` |
| `subagent_type: "poteto-agent"` or `"comment-sicko"` | Same name. `install.sh` puts both in `~/.claude/agents/`. | Default agent. Start the message with "Read `<pstack>/agents/<name>.md` and follow it as your instructions." |
| `readonly: true` | Add "Read-only. Do not edit files." to the prompt, or use `subagent_type: "Explore"` for pure search | Same prompt line |
| `readonly: false` (agent mode, keeps MCP) | Default. Subagents keep MCP tools. | Default |
| `run_in_background: true` | `run_in_background: true` | Spawns are already concurrent. Call `wait_agent` when you need the result. |
| `environment: "cloud"` | `isolation: "remote"` when available, else `isolation: "worktree"` | Local only. Give each writing worker its own `git worktree`. |
| `environment: "local"` | Omit `isolation`, or `isolation: "worktree"` for writers | Default |
| `model: <slug>` | `model: <alias>` (see Model configuration) | `model: <slug>`, plus `reasoning_effort` |
| Resume an agent | `SendMessage` to its id | `send_input` to its id (`resume_agent` if closed) |
| `AskQuestion` | `AskUserQuestion` | Ask in plain text with numbered options |
| Todo list | `TaskCreate` / `TodoWrite`, whichever the session offers | `update_plan` |

## Cross-family runs

Run these through the shell in the background, one process per panel member, and give each its own output file. The child gets no conversation context, so pass file paths and the full brief, as you would for any subagent.

From Claude Code to Codex:

```bash
codex exec --skip-git-repo-check -C "$PWD" -s read-only \
  [-m <model>] [-c model_reasoning_effort=<effort>] \
  -o "$OUT/<label>.md" "<brief>"
```

Use `-s workspace-write` when the runner writes code, and run it in its own `git worktree`.

From Codex to Claude Code:

```bash
claude -p --model <model> [--effort <effort>] \
  --disallowedTools "Edit Write NotebookEdit" \
  "<brief>" > "$OUT/<label>.md"
```

Drop `--disallowedTools` when the runner writes code, and run it in its own `git worktree`. Add `--permission-mode acceptEdits` so it does not stop for approval.

## Paths

| Cursor | Claude Code | Codex |
|---|---|---|
| `~/.cursor/skills/`, `~/.cursor/plugins/` | `~/.claude/skills/` (pstack installs through `~/.agents/skills/`) | `~/.agents/skills/` |
| Project `.cursor/skills/<name>/` | Project `.claude/skills/<name>/` | Project `.agents/skills/<name>/` |
| Project skill shared by both | `.agents/skills/<name>/` plus a `.claude/skills/<name>` symlink to it | `.agents/skills/<name>/` |
| `~/.cursor/rules/pstack-models.mdc` | `~/.agents/pstack-models.md` | `~/.agents/pstack-models.md` |
| `~/.cursor/projects/<slug>/agent-transcripts/` | `~/.claude/projects/<slug>/*.jsonl`. The slug is the absolute cwd with every character other than a letter or digit turned into `-`. | `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl`. The first line's `session_meta` holds the `cwd`. Match it to the workspace. |

Keep the privacy rule from every skill that reads transcripts. Read only the transcripts of the active workspace. Never glob across every project or every session.

## Cursor-only features

| Cursor | Claude Code | Codex |
|---|---|---|
| Custom Mode (Option+Enter keeps a skill on) | None. Start each task with `/poteto-mode`. | None. Start each task with `$poteto-mode` or name the skill. |
| `/loop` | `/loop` | None. Keep working in the same turn, or poll with a shell `sleep` loop. |
| Built-in `create-skill` | The `skill-creator` skill when installed, else the Agent Skills format directly | The built-in `skill-creator` |
| `cursor-team-kit` `/deslop` | The **unslop** and **no-comments** skills over the diff | Same |
| `cursor-team-kit` `control-ui` | A browser automation skill or MCP (Claude in Chrome, Playwright MCP) | Playwright or a browser MCP |
| `cursor-team-kit` `control-cli` | Drive the CLI through the shell, `tmux` for TUIs | Same |
| Cursor's built-in babysit skill | Not present. Use the Babysit playbook. | Same |
| Plan Mode | Plan mode (`EnterPlanMode`) | Ask for a plan before any edits |
| Bugbot, agentic security review | Whatever review bots the repo runs. Treat them the same way. | Same |
| Cloud-agent URL, Cursor dashboard | A cloud session (claude.ai/code, `--teleport` to pull it local) when available | None. Work from pushed branches and PRs. |
| A Cursor restart | A Claude Code restart. Background agents die with the session. | A Codex restart. Spawned agents die with the session. |
