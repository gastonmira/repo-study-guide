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

### 0. MCP preflight (MANDATORY when available)

**Before any `Read`, `Grep`, `Glob`, or `find` call for code exploration, you MUST attempt the [`code-review-graph`](https://github.com/tirth8205/code-review-graph) MCP.** Reading project metadata (`README.md`, `package.json`, `pyproject.toml`, etc.) is allowed in parallel — the graph does not cover those.

1. Call `mcp__code-review-graph__list_graph_stats_tool`. If it responds (even with `Nodes: 0` / `Last updated: never`), the MCP is available and **must be used** for steps 1–2.
2. If the stats show `Nodes: 0` or stale data, call `mcp__code-review-graph__build_or_update_graph_tool` (idempotent; incremental updates run in <2s) before continuing.
3. Only if the tool errors out, is not registered, or returns a hard failure, fall back to the shell-based flow described inline in steps 1–2.

Skipping this preflight when the MCP is available is a **skill violation** — the resulting study guide will be missing hub ranks, community structure, and impact data that the graph provides and the template expects.

### 1. Exploration phase

Goal: build a mental model in the minimum number of reads.

- **Size probe (first)** — measure the repo before reading anything:
  - Primary: `mcp__code-review-graph__list_graph_stats_tool` (already called in Step 0) — use the reported node/file count.
  - Fallback (MCP unavailable): `find . -type f -not -path './.git/*' -not -path './node_modules/*' -not -path './dist/*' -not -path './build/*' | wc -l`.
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
  - **Architecture (MCP-first, mandatory if available)**: call `mcp__code-review-graph__get_architecture_overview_tool` for the high-level layout (modules, layers, key boundaries). This replaces manual folder scanning.
  - **Shell fallback** (only if MCP unavailable): `ls -la`, `find . -maxdepth 3 -type f`, or `rg --files` to map the root and obvious source folders (`src/`, `lib/`, `app/`, `pkg/`, `cmd/`, etc.).
  - **Identity files** — read in parallel: `README.md`, `package.json`, `pyproject.toml`, `requirements.txt`, `Cargo.toml`, `go.mod`, `pom.xml`, `Gemfile`. (Always needed — the graph does not capture project metadata.)
  - **Type detection** — classify as one of: CLI, Web App, Library/SDK, ML/Data project, Monorepo, Infra/IaC. Use the architecture overview + identity files together.

### 2. Analysis phase

- **Entry point** — use `mcp__code-review-graph__list_flows_tool`, then `mcp__code-review-graph__get_flow_tool` on the main flow. Fallback (MCP unavailable): locate `main.*`, `index.*`, `app.*`, `cli.*`, `__main__.py`, or the `"main"`/`"bin"` field in `package.json`.
- **Data flow** — trace one realistic input from entry → core logic → output via `get_flow_tool`; only `Read` the specific files it surfaces.
- **Core logic** (3–7 files) — use `mcp__code-review-graph__get_hub_nodes_tool` (top files by in/out-degree) and `mcp__code-review-graph__list_communities_tool` to group related modules. **Both calls are mandatory when the MCP is available** — their output feeds the Hub rank column and Communities section of the template (see step 3b). Fallback: `rg` for exported symbols, route definitions, command handlers, or model classes.
- **Targeted symbol/route lookup** — use `mcp__code-review-graph__semantic_search_nodes_tool` before `rg`. Fall back to `rg` only for non-indexed languages or empty results.
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
  - `{{CORE_MODULES}}` — table rows: file path · 1-sentence role. **When the MCP is available**, add a **Hub rank** column populated from `get_hub_nodes_tool` (in/out-degree). Do not infer hubs from folder structure.
  - **Communities block** — when `list_communities_tool` is available, include a short paragraph or sub-table inside `{{OVERVIEW}}` or `{{CORE_MODULES}}` with: community count, cohesion scores, and cross-community edge count. This is the observable signal that the graph was used.
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
- **MCP-first when available** — if `code-review-graph` tools respond, they **MUST** be used for structural exploration. Falling back to `Read`/`Grep`/`find` without first attempting the graph is a skill violation. Use `get_minimal_context_tool` / `get_review_context_tool` to pull only the snippets the template actually needs.

## Final checklist (must pass before reporting done)

- [ ] `<output_dir>/study_guide.html` exists and opens in a browser without console errors.
- [ ] `<output_dir>/architecture.mmd` parses (sanity check: balanced brackets, no empty graph).
- [ ] All `{{PLACEHOLDERS}}` replaced — `rg -c '{{' study_guide.html` returns no matches, or `grep -c '{{' study_guide.html` returns `0`.
- [ ] Sidebar TOC has working anchors for every `<section>`.
- [ ] Mermaid block renders (if CDN unreachable, fallback message is visible).
- [ ] If `code-review-graph` MCP was available, at least `list_graph_stats_tool` + one of `get_architecture_overview_tool` / `get_hub_nodes_tool` / `list_communities_tool` were invoked during exploration.
- [ ] When the MCP was available, the Hub rank column and Communities block in the HTML are populated from graph data (not inferred from folder names).

## Activation Trigger

- Manual: `$repo-study-guide` in Codex, `/skill repo-study-guide` in Claude Code, or the host agent's explicit skill invocation syntax.
- Contextual: "Analyze this repo", "Generate a study guide", "Explain this codebase", "Onboard me to this project".
