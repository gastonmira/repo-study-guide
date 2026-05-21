---
name: repo-study-guide
description: Analyze any repository and generate a self-contained dark-themed HTML study guide plus a Mermaid architecture diagram. Use when the user asks to "analyze this repo", "generate a study guide", "explain this codebase", or wants a visual onboarding doc for a project.
---

# Repo Study Guide Skill

Universal instruction set to analyze any repository and produce a high-quality, self-contained HTML study guide plus an architecture diagram. Compatible with Claude Code, Codex, and other code agents that can read this skill and bundled template.

## When to use

Trigger this skill when the user:
- Opens an unfamiliar repo and wants a fast mental model.
- Asks for "study guide", "onboarding doc", "architecture overview", or "explain this codebase".
- Wants a visual artifact (HTML + Mermaid) instead of a chat-only explanation.

## Inputs

- **Target repo path** (default: current working directory).
- **Output directory** (default: `docs/` relative to the repo root; override if the user asks).

## Execution Steps

### Token-efficient mode (code-review-graph)

If the host agent exposes the [`code-review-graph`](https://github.com/tirth8205/code-review-graph) MCP server (tools named `mcp__code-review-graph__*`), prefer those tools over shell scans and bulk `Read` calls in steps 1 and 2. The graph returns structural facts (entry points, hubs, communities, flows, minimal context) at a fraction of the tokens that re-reading whole files would cost.

Detection is implicit: just try the graph tool first. **If any graph tool errors, is not available, or returns empty, fall back to the shell-based step described immediately below it.** No hard dependency — when the MCP is absent, the original flow stands unchanged.

### 1. Exploration phase

Goal: build a mental model in the minimum number of reads.

- **Size probe (first)** — measure the repo before reading anything:
  - With graph: `mcp__code-review-graph__list_graph_stats_tool` and read the file/node count.
  - Without graph: `find . -type f -not -path './.git/*' -not -path './node_modules/*' -not -path './dist/*' -not -path './build/*' | wc -l`.
- **If >500 files → delegate to a subagent (default)**. Spawn an `Explore` subagent so its context is discarded after the brief returns, keeping the main context lean. Use this prompt verbatim (substitute `<repo path>`):

  ```
  Explore <repo path>. Return a Markdown brief (<800 words) with:
  - One-paragraph purpose (derived from README + package metadata).
  - Project type: CLI / Web App / Library / ML-Data / Monorepo / Infra-IaC.
  - 3 entry points with file:line.
  - Top 10 hub files by import-fan-in (use mcp__code-review-graph__get_hub_nodes_tool if available, else rg/grep).
  - Logical modules / communities (use mcp__code-review-graph__list_communities_tool if available).
  - Identity-file highlights: install command, run command, main deps.
  - One realistic data-flow trace: entry → core → output, naming each module.
  Do not include source code excerpts unless ≤5 lines. Do not include full files.
  ```

  Skip steps 1 and 2 below and feed the brief directly into step 3. Only re-open specific files later if the template demands a snippet you don't have.

- **If ≤500 files → inline exploration** (continue with the steps below):
  - **Graph-first (if available)**:
    - `mcp__code-review-graph__build_or_update_graph_tool` — ensure the graph is fresh (idempotent; incremental updates run in <2s).
    - `mcp__code-review-graph__get_architecture_overview_tool` — high-level layout (modules, layers, key boundaries). Replaces manual folder scanning.
  - **Shell fallback** — `ls -la`, `find . -maxdepth 3 -type f`, or `rg --files` to map the root and obvious source folders (`src/`, `lib/`, `app/`, `pkg/`, `cmd/`, etc.).
  - **Identity files** — read in parallel: `README.md`, `package.json`, `pyproject.toml`, `requirements.txt`, `Cargo.toml`, `go.mod`, `pom.xml`, `Gemfile`. (Always needed — the graph does not capture project metadata.)
  - **Type detection** — classify as one of: CLI, Web App, Library/SDK, ML/Data project, Monorepo, Infra/IaC. Use the architecture overview + identity files together.

### 2. Analysis phase

- **Entry point**
  - Graph-first: `mcp__code-review-graph__list_flows_tool` then `mcp__code-review-graph__get_flow_tool` on the main flow.
  - Fallback: locate `main.*`, `index.*`, `app.*`, `cli.*`, `__main__.py`, or the `"main"`/`"bin"` field in `package.json`.
- **Data flow** — trace one realistic input from entry → core logic → output. Prefer `get_flow_tool` on the chosen flow; only `Read` the specific files it surfaces.
- **Core logic** (3–7 files)
  - Graph-first: `mcp__code-review-graph__get_hub_nodes_tool` (top files by fan-in/out) plus `mcp__code-review-graph__list_communities_tool` to group related modules.
  - Fallback: `rg` for exported symbols, route definitions, command handlers, or model classes; `grep`/`find` if `rg` is unavailable.
- **Targeted symbol/route lookup** — prefer `mcp__code-review-graph__semantic_search_nodes_tool` before `rg`. Falls back to `rg` for non-indexed languages or empty results.
- **Reading snippets for the template** — use `mcp__code-review-graph__get_minimal_context_tool` or `get_review_context_tool` to pull only the lines needed for `{{MINIMAL_EXAMPLE}}` and `{{CORE_MODULES}}` rather than full-file `Read` calls.
- **External surface** — APIs exposed, CLI commands, env vars, config files. Combine `semantic_search_nodes_tool` (handlers, routes) with the usual config-file reads.

### Edge cases

- **Monorepos** — detect `workspaces` (`package.json`), `pnpm-workspace.yaml`, Turborepo, Nx, Cargo workspaces. When the graph is available, `list_communities_tool` often surfaces logical packages as distinct communities — cross-reference with workspace config. Generate one study guide *per workspace package* under `docs/<package>/study_guide.html`, plus a root index.
- **No README** — derive purpose from package metadata, top-level comments, and folder names. Mark the "Purpose" section as `(inferred)`.
- **Empty / scaffolding only** — produce a minimal guide noting the repo is a scaffold; suggest next steps instead of forcing analysis.
- **Unknown language** — fall back to file-extension stats and any build configs found.

### 3. Artifact Generation

#### 3a. Architecture diagram

- Create a Mermaid `graph TD` (for component/module relationships) or `sequenceDiagram` (for request/data flow).
- Keep it to **≤15 nodes** — high-level only, no leaf files.
- Save to `<output_dir>/architecture.mmd`.

#### 3b. HTML study guide

- Load `templates/study_guide_template.html` (sibling of this `SKILL.md`).
- Replace placeholders:
  - `{{PROJECT_NAME}}`
  - `{{PROJECT_TYPE}}` (CLI / Web App / Library / etc.)
  - `{{OVERVIEW}}` — 2–3 sentences, what it does.
  - `{{PURPOSE}}` — why it exists, problem solved.
  - `{{STEP_BY_STEP}}` — ordered list tracing the data flow.
  - `{{CORE_MODULES}}` — table rows: file path · 1-sentence role.
  - `{{MINIMAL_EXAMPLE}}` — smallest runnable snippet.
  - `{{LOCAL_SETUP}}` — install + run commands.
  - `{{MERMAID_DIAGRAM}}` — inline contents of `architecture.mmd`.
  - `{{GENERATED_AT}}` — ISO date.
  - `{{COMMIT_HASH}}` — output of `git rev-parse --short HEAD` if it's a git repo, else empty.
- Save to `<output_dir>/study_guide.html`.

## Quality Standards

- **English only** — professional technical English in all output.
- **Visual-first** — diagrams, tables, and code blocks over prose.
- **Zero fluff** — every sentence must help a first-time reader. No filler.
- **Self-contained** — HTML must open offline (CDN scripts are okay only if the template ships fallbacks).
- **Reproducible** — same repo state → same output. Don't invent details; mark inferences as such.
- **Token-efficient** — when the code-review-graph MCP is available, prefer graph queries over full-file reads. Use `get_minimal_context_tool` / `get_review_context_tool` to pull only the snippets the template actually needs.

## Final checklist (must pass before reporting done)

- [ ] `<output_dir>/study_guide.html` exists and opens in a browser without console errors.
- [ ] `<output_dir>/architecture.mmd` parses (sanity check: balanced brackets, no empty graph).
- [ ] All `{{PLACEHOLDERS}}` replaced — `rg -c '{{' study_guide.html` returns no matches, or `grep -c '{{' study_guide.html` returns `0`.
- [ ] Sidebar TOC has working anchors for every `<section>`.
- [ ] Mermaid block renders (if CDN unreachable, fallback message is visible).

## Activation Trigger

- Manual: `$repo-study-guide` in Codex, `/skill repo-study-guide` in Claude Code, or the host agent's explicit skill invocation syntax.
- Contextual: "Analyze this repo", "Generate a study guide", "Explain this codebase", "Onboard me to this project".
