---
name: qmd
description: Search past session notes, reviews, reports and plans under tmp/, the repo's docs, and its .claude/ rules and skills with the local qmd CLI, inline, and answer with cited paths. Use when asked what was previously found, decided, reviewed or tried ("what did we learn about X", "have we reviewed this before", "find the report on Y"), before redoing an investigation or review that may already exist in tmp/, when a decision's history matters, or to find where a behavior lives in the code when you don't know its name.
---

# qmd

`qmd` is a local hybrid search CLI (BM25 + vectors, optional rerank, all on CPU). Run it yourself
through Bash and read only the hits you need. Do not hand the search to a subagent.

## Collections

`<repo>` is the basename of `git rev-parse --show-toplevel`. `qmd collection list` is the source of
truth, `~/.config/qmd/index.yml` the config.

| Collection | Covers |
|---|---|
| `<repo>-tmp` | past session work under `tmp/` |
| `<repo>-docs` | repo markdown outside `tmp/` |
| `<repo>-claude` | `.claude/` rules, skills, agents |
| `<repo>-code` | `.go`, `.js`, `.ts`, `.tsx` outside `tmp/`, minus generated code, mocks and fixtures |

Search `<repo>-code` on its own (`-c <repo>-code`) when you don't know an identifier and need to
find where a behavior lives. When you know the name, use `rg` or the LSP instead: they are exact
and always match the working tree, while the index only catches up when a turn ends.

If the repo has none, say so and offer to add them (`qmd collection add "<path>" --name "<name>"
--mask '**/*.md'`; `ignore` globs are YAML-only, then `qmd update`).

## Recipe

1. The `qmd-refresh` hook re-indexes at session start, turn end and on edits, so don't run
   `qmd update` or `qmd embed` yourself. Check `qmd status` first. If it shows documents that
   need embedding, stop and report it as an error: the vector index is incomplete (a refresh is
   still running or failed, log: `~/.cache/qmd/refresh.log`) and results would be wrong. Do not
   answer from a partial index.
2. Search, capped:
   ```bash
   qmd query "<focused question>" -c <repo>-tmp -c <repo>-docs -c <repo>-claude -n 5 --full-path --no-rerank
   ```
   - Never use `qmd search` (keyword-only BM25), not as a fallback and not for identifiers. Put exact identifiers (ticket keys, PR numbers, error strings) into the `qmd query` text instead.
   - Thin hits: rephrase or raise `-n` to 10 once. Drop `--no-rerank` only as a last resort, it costs a minute or two per query.
3. Read before asserting, a slice at a time: `qmd get <path>:<line>:60` around the hit line, not
   `--full`, unless the document is short.
4. Answer in prose, cite every claim with its path, and use the `YYYY-MM-DD_` folder prefix to say
   how old a finding is. Newer documents win over older ones; say when they disagree. Say plainly
   when the notes don't cover it.

## Rules

- Notes record what someone believed at the time. When an answer would drive a code change, check it against the current code.
- Never run `qmd collection remove`, `qmd embed -f` or `qmd cleanup` unless asked; rebuilding on CPU takes a long time.
- If a qmd command errors or models fail to load, report the exact error. Do not answer from memory instead.
