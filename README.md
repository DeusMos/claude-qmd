# claude-qmd

A Claude Code plugin for local semantic search over a repo using [qmd](https://github.com/tobi/qmd). Claude searches your past session notes under `tmp/`, the repo's docs, its `.claude/` rules and skills, and its code, then answers with cited paths.

Everything runs on your machine: no API calls, and nothing leaves the box. Each person indexes their own checkout, so `tmp/` search covers your own past sessions, not your team's.

The plugin contains:

- `skills/qmd`: tells Claude when and how to search, and to read hits before asserting anything.
- `hooks/qmd-refresh`: re-indexes in the background at session start, at the end of each turn, and after edits to `.md`, `.go`, `.js`, `.ts` and `.tsx` files.

## Requirements

- Node.js 22 or newer (or Bun 1.0+)
- `jq`, `flock` and `setsid` on `PATH` (standard on Linux; on macOS `brew install jq util-linux`)
- macOS only: `brew install sqlite` (qmd needs Homebrew SQLite for its vector extension)
- About 2.2 GB of disk for models in `~/.cache/qmd/models/`, downloaded on first use
- Patience on CPU: the first full embed of a large repo takes a long time, and a reranked query takes one to two minutes. `qmd doctor` reports whether a GPU is being used.

## 1. Install qmd

```bash
npm install -g @tobilu/qmd
qmd --version
```

Tested with qmd 2.8.3.

## 2. Install the plugin

```bash
claude plugin marketplace add DeusMos/claude-qmd
claude plugin install qmd@deusmos
```

This installs the skill and the refresh hook together. Plugin skills keep the plugin name as a prefix, so the skill is `/qmd:qmd`. Claude also picks it up on its own when you ask what was previously found, decided or tried.

## 3. Create the collections

One set per repo. `<repo>` must be the basename of `git rev-parse --show-toplevel`, because that is how the skill finds them.

```bash
root=$(git rev-parse --show-toplevel)
repo=$(basename "$root")
qmd collection add "$root/tmp"     --name "$repo-tmp"    --mask '**/*.md'
qmd collection add "$root"         --name "$repo-docs"   --mask '**/*.md'
qmd collection add "$root/.claude" --name "$repo-claude" --mask '**/*.md'
qmd collection add "$root"         --name "$repo-code"   --mask '**/*.{go,js,ts,tsx}'
```

`ignore` globs can only be set in the config file. Edit `~/.config/qmd/index.yml` so each collection has its ignores. Example for a repo called `myrepo`:

```yaml
collections:
  myrepo-tmp:
    path: /path/to/myrepo/tmp
    pattern: "**/*.md"
  myrepo-claude:
    path: /path/to/myrepo/.claude
    pattern: "**/*.md"
    ignore: ["worktrees/**"]
  myrepo-docs:
    path: /path/to/myrepo
    pattern: "**/*.md"
    ignore: ["tmp/**"]
  myrepo-code:
    path: /path/to/myrepo
    pattern: "**/*.{go,js,ts,tsx}"
    ignore: ["tmp/**", "**/mocks/**", "**/fixture/**"]
```

Why each ignore matters:

- `.claude/worktrees/**` holds full repo copies made for agent worktrees. Without the ignore, every doc shows up many times over.
- `tmp/**` on `-docs` and `-code` stops them re-indexing what `-tmp` already covers, including git worktrees under `tmp/`.
- The `-code` ignores drop test doubles. Add your repo's generated-code directories too.
- `.claude/` needs its own collection because qmd skips hidden directories under a collection's root. qmd also always skips `node_modules`, `.git`, `.cache`, `vendor`, `dist` and `build`.

`collection add` indexes straight away, so files in ignored paths get indexed first. Run `qmd update` after editing the YAML to drop them.

## 4. Build the index

```bash
qmd update
qmd embed
qmd status
```

`qmd status` must show nothing left to embed. The skill refuses to answer from a partially embedded index and reports it as an error instead, so let the first embed finish. Run it in the background for a large repo. After that the hook keeps it current, and its log is `~/.cache/qmd/refresh.log`. If a refresh fails, the next hook run puts the error into the Claude session.

## Check it works

```bash
qmd status
qmd query "what did we decide about X" -c "$repo-tmp" -c "$repo-docs" -c "$repo-claude" -n 5 --full-path --no-rerank
tail ~/.cache/qmd/refresh.log
```

## Don't

- Run `qmd embed -f`, `qmd collection remove` or `qmd cleanup` casually. They throw away embeddings that take a long time to rebuild on CPU.
