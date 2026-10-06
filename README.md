# herdr-sbx

Run coding agents in [Docker Sandboxes](https://docs.docker.com/ai/sandboxes/) (`sbx`) from
[herdr](https://herdr.dev) tabs. Each task gets its own microVM working on a private clone of
the repo, so nothing the agent writes reaches your checkout until you fetch and review it.

It also ships a Claude Code skill, `sbx-orchestrate`, that runs a whole markdown plan through
these sandboxes: one sandbox per task, in dependency waves, each result checked in a fresh
sandbox and reviewed by a second agent, ending in one pull request per task. It never merges.

## Requirements

- zsh, git, jq
- [herdr](https://herdr.dev) for tabs and agent state
- Docker Sandboxes (`sbx`)
- `gh`, authenticated, for the orchestration skill

## Setup (once per machine)

```zsh
./install.sh                                    # symlinks bin/* into ~/.local/bin
cat herdr.toml >> ~/.config/herdr/config.toml && herdr server reload-config
sbx settings set ssh.agentForwardingEnabled false && sbx daemon restart
```

## Agents

The last argument of `sbx-task` and `sbx-dispatch` picks the agent. A kit under `kits/<agent>`
wins; anything else is an sbx built-in. Logins live on the host, and the VM sees placeholders.

| Agent | Role | Login, once per machine |
|---|---|---|
| `pi` | implementer (z.ai `glm-5.3-flash`, `kits/pi`) | `sbx secret set-custom --host api.z.ai --env ZAI_API_KEY --command '<prints your z.ai key>'`, e.g. a password manager CLI |
| `codex` | reviewer | `sbx secret set openai --oauth` |
| `claude` | alternate | `/login` inside any Claude sandbox |
| `cursor` | alternate | sign in inside any Cursor sandbox |

## Loop

1. `prefix+alt+a` in herdr, type a task name and optionally an agent (default `pi`). Opens a tab running
   `sbx run --clone --name <repo>-<task> <agent> .`
2. herdr notifies when the agent is done or blocked.
3. Test inside the VM: `sbx exec <repo>-<task> <test command>`
4. Review: `sbx-review <repo>-<task> [base]` fetches its branches and flags changed files
   that execute on the host (CI, hooks, Makefile, package.json, .claude/).
5. Land: `git switch -c <branch> sandbox-<repo>-<task>/<branch>`, push from the host.
6. `sbx rm -f <repo>-<task>`. Fetched branches survive under `refs/sandboxes/<name>/`.

## Orchestrating a plan

Install the skill as a Claude Code plugin:

```zsh
claude plugin marketplace add vot3k/herdr-sbx && claude plugin install herdr-sbx@herdr-sbx
```

Then ask Claude to "run plan docs/plans/add-auth.md with herdr-sbx". The skill reads the task
contracts, dispatches them in dependency waves with `bin/sbx-dispatch`, judges each result
with `bin/sbx-collect` (paths, commit, exit codes only), has Codex review it in another
sandbox, and opens one PR per task on `plan/<planId>/<slug>`. Each run gets its own herdr
workspace: a tab per task, with its reviewer in a pane beside the worker. A ledger under
`~/.cache/herdr-sbx/runs/` lets a later session resume.

### Plan format

```markdown
# Add auth

Repo: ~/dev/myapp
Check: npm ci && npm test

## Task: Add session store

Slug: session-store
Files:
- src/session.ts
- test/session.test.ts
Prompt:
Add a `SessionStore` class in src/session.ts with get/set/delete backed by a Map.
Cover it in test/session.test.ts.

## Task: Add login route

Slug: login-route
dependsOn: session-store
Agent: claude
Files:
- src/routes/
Prompt:
...
```

`Slug`, `Files` and `Prompt` are required. `Check` and `Agent` can be set per task. A `Files`
entry ending in `/` covers a directory. A task starts only after the PRs of its `dependsOn`
tasks are merged.

## Why these choices

- `--clone`: the host repo is mounted read-only; a direct mount would let the agent edit
  git hooks and build files that later run on the host.
- `HERDR_AGENT=<agent>`: sbx hides the agent process, so herdr needs the hint to detect it.
- SSH forwarding off: clone mode copies `origin` into the VM and github.com:22 is
  reachable, so a forwarded key would let the agent push.
- No `github` secret: pushing happens on the host, after review.
- Host worktrees are not used: a sandbox mounting one cannot resolve `.git`.
- The orchestrator decides only from facts produced by code (exit codes, changed paths, a
  commit hash, a schema-checked review verdict), never from transcripts, logs or file
  contents. Agent output can carry prompt injection, and the host holds your keys.

## License

MIT
