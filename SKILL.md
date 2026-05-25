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

### 0. MCP preflight

Before any `Read`, `Grep`, `Glob`, or `find` call for code exploration, attempt the [`code-review-graph`](https://github.com/tirth8205/code-review-graph) MCP by calling `mcp__code-review-graph__list_graph_stats_tool`. If it is unavailable or returns a hard failure, continue with the shell fallbacks in steps 1–2. See [`reference/mcp-usage.md`](reference/mcp-usage.md) for the full preflight contract, stale/empty graph handling, tool catalog, and fallbacks.

### 0b. Graph coverage gate

After the preflight, check whether the graph is representative before using it for architecture, hubs, communities, or graph summary output. Treat the graph as **low coverage** when it indexes no files, only a tiny subset of the repo, or mostly test files. For low-coverage graphs, use shell/file exploration as the source of truth, omit `{{GRAPH_SUMMARY}}`, do not add Hub rank values from the graph, and mention the graph limitation only in the final response.

### 1. Exploration phase

Goal: build a mental model in the minimum number of reads.

- **Size probe (first)** — measure the repo before reading anything:
  - Run the shell file count even when the graph responds: `find . -type f -not -path './.git/*' -not -path './node_modules/*' -not -path './dist/*' -not -path './build/*' | wc -l`.
  - Compare it with `mcp__code-review-graph__list_graph_stats_tool` from Step 0. If graph file coverage is clearly incomplete, mark the graph low coverage and use the shell count for the >500-file decision.
- **If >500 files → delegate to a subagent (default)**. Spawn an `Explore` subagent so its context is discarded after the brief returns, keeping the main context lean. Use this prompt verbatim (substitute `<repo path>`):

  ```
  Explore <repo path>. Return a Markdown brief (<800 words) with:
  - One-paragraph purpose (derived from README + package metadata).
  - Project type: CLI / Web App / Library / ML-Data / Monorepo / Infra-IaC.
  - 3 entry points with file:line.
  - Top 10 hub files by import-fan-in (use graph hubs only if graph coverage is representative, else rg/grep).
  - Logical modules / communities (use graph communities only if graph coverage is representative).
  - Identity-file highlights: install command, run command, main deps.
  - One realistic data-flow trace: entry → core → output, naming each module.
  Do not include source code excerpts unless ≤5 lines. Do not include full files.
  ```

  Skip steps 1 and 2 below and feed the brief directly into step 3. Only re-open specific files later if the template demands a snippet you don't have.

- **If ≤500 files → inline exploration** (continue with the steps below):
  - **Architecture**: if graph coverage is representative, call `mcp__code-review-graph__get_architecture_overview_tool` for the high-level layout (modules, layers, key boundaries). If graph coverage is low or MCP is unavailable, use `ls -la`, `find . -maxdepth 3 -type f`, or `rg --files` to map the root and obvious source folders (`src/`, `lib/`, `app/`, `pkg/`, `cmd/`, etc.).
  - **Identity files** — read in parallel: `README.md`, `package.json`, `pyproject.toml`, `requirements.txt`, `Cargo.toml`, `go.mod`, `pom.xml`, `Gemfile`. (Always needed — the graph does not capture project metadata.)
  - **Type detection** — classify as one of: CLI, Web App, Library/SDK, ML/Data project, Monorepo, Infra/IaC. Use the architecture overview + identity files together.

### 2. Analysis phase

- **Entry point** — when graph coverage is representative, use `mcp__code-review-graph__list_flows_tool`, then `mcp__code-review-graph__get_flow_tool` on the main flow. Fallback (low coverage or MCP unavailable): locate `main.*`, `index.*`, `app.*`, `cli.*`, `__main__.py`, or the `"main"`/`"bin"` field in `package.json`.
- **Data flow** — when graph coverage is representative, trace one realistic input from entry → core logic → output via `get_flow_tool`; only `Read` the specific files it surfaces. With low graph coverage, trace the flow from entry points, routes, handlers, commands, or package metadata using focused file reads.
- **Core logic** (3–7 files) — when graph coverage is representative, use `mcp__code-review-graph__get_hub_nodes_tool` (top files by in/out-degree) and `mcp__code-review-graph__list_communities_tool` to group related modules. Their output feeds the Hub rank column and graph summary note in the template (see step 3b). When graph coverage is low or MCP is unavailable, use `rg` for exported symbols, route definitions, command handlers, or model classes and leave Hub rank blank or mark it as shell-derived context without graph ranks.
- **Targeted symbol/route lookup** — when graph coverage is representative, use `mcp__code-review-graph__semantic_search_nodes_tool` before `rg`. Fall back to `rg` for low coverage, non-indexed languages, or empty graph results.
- **Reading snippets for the template** — when graph coverage is representative, use `mcp__code-review-graph__get_minimal_context_tool` or `get_review_context_tool` to pull only the lines needed for `{{MINIMAL_EXAMPLE}}` and `{{CORE_MODULES}}` rather than full-file `Read` calls. With low graph coverage, use focused file reads.
- **External surface** — APIs exposed, CLI commands, env vars, config files. When graph coverage is representative, combine `semantic_search_nodes_tool` (handlers, routes) with the usual config-file reads. With low graph coverage, use focused `rg` and config-file reads.

### Edge cases

See [`reference/edge-cases.md`](reference/edge-cases.md) for monorepos, repos without a README, scaffolds, and non-indexed languages.

### 3. Artifact Generation

#### 3a. Architecture diagram

- Create a Mermaid `graph TD` (for component/module relationships) or `sequenceDiagram` (for request/data flow).
- Keep it to **≤15 nodes** — high-level only, no leaf files.
- Prefer readable clustered diagrams: use `subgraph` blocks when the repo has distinct install-time, runtime, integration, test, or data layers; use short human labels; avoid numeric details as primary nodes; and choose `graph LR` when it reduces edge crossings.
- Save to `<output_dir>/architecture.mmd`.

#### 3b. HTML study guide

- Load `templates/study_guide_template.html` (sibling of this `SKILL.md`).
- Replace placeholders:
  - `{{PROJECT_NAME}}`
  - `{{PROJECT_TYPE}}` (CLI / Web App / Library / etc.)
  - `{{OVERVIEW}}` — 2–3 sentences, what it does.
  - `{{GRAPH_SUMMARY}}` — if representative graph data is available, a `<p class="note">` paragraph that explains the graph signals in plain English before listing values. It must define the metrics in the generated text: "nodes" are indexed code entities such as files/functions/classes, "edges" are detected relationships such as imports/calls/containment, "communities" are clusters of related code, "cohesion" is how tightly connected a cluster is, and "cross-community edges" are detected links between clusters. Include only the most useful 2–4 values or community names, and phrase surprising values (for example `0` cross-community edges) as "the graph reported" rather than as an absolute architectural fact. If graph data is unavailable or low coverage, replace with an empty string.
  - `{{PURPOSE}}` — why it exists, problem solved.
  - `{{STEP_BY_STEP}}` — ordered list tracing the data flow.
  - `{{CORE_MODULES}}` — table rows: file path · 1-sentence role. **When the MCP is available**, add a **Hub rank** column populated from `get_hub_nodes_tool` (in/out-degree). Do not infer hubs from folder structure.
  - **Communities signal** — when `list_communities_tool` is available, summarize community count, cohesion scores, and cross-community edge count in `{{GRAPH_SUMMARY}}`. This is the observable signal that the graph was used.
  - `{{MINIMAL_EXAMPLE}}` — smallest runnable snippet.
  - `{{LOCAL_SETUP}}` — install + run commands.
  - `{{MERMAID_DIAGRAM}}` — inline contents of `architecture.mmd`.
  - `{{ARCHITECTURE_EXPLANATION}}` — a short paragraph or `<p class="note">` under the diagram explaining how to read it: the main entry points, the direction of the flow, what each cluster/layer represents, and which arrows are install-time vs runtime vs integration/test relationships. If the diagram is trivial, replace with an empty string.
  - `{{GENERATED_AT}}` — ISO date.
  - `{{COMMIT_HASH}}` — output of `git rev-parse --short HEAD` if it's a git repo, else empty.
- Save to `<output_dir>/study_guide.html`.

## Quality Standards

- **English only** — professional technical English in all output.
- **Visual-first** — diagrams, tables, and code blocks over prose.
- **Zero fluff** — every sentence must help a first-time reader. No filler.
- **Self-contained** — HTML must open offline (CDN scripts are okay only if the template ships fallbacks).
- **Reproducible** — same repo state → same output. Don't invent details; mark inferences as such.
- **MCP-first when available** — see [`reference/mcp-usage.md`](reference/mcp-usage.md).

## Final checklist (must pass before reporting done)

- [ ] `<output_dir>/study_guide.html` exists and opens in a browser without console errors.
- [ ] `<output_dir>/architecture.mmd` parses (sanity check: balanced brackets, no empty graph).
- [ ] All `{{PLACEHOLDERS}}` replaced — `rg -c '{{' study_guide.html` returns no matches, or `grep -c '{{' study_guide.html` returns `0`.
- [ ] Sidebar TOC has working anchors for every `<section>`.
- [ ] Mermaid block renders (if CDN unreachable, fallback message is visible).
- [ ] Large architecture diagrams remain readable: zoom controls are present, reset works, and the diagram can scroll horizontally/vertically inside its viewport.
- [ ] If `code-review-graph` MCP was available, `list_graph_stats_tool` was invoked first and graph coverage was compared with the repo file count before graph data was used.
- [ ] When representative MCP graph data was available, the Hub rank column and graph summary note in the HTML are populated from graph data (not inferred from folder names) and explain the metrics in plain English. When graph coverage was low, graph-derived summary and hub ranks are omitted.

## Activation Trigger

- Manual: `$repo-study-guide` in Codex, `/skill repo-study-guide` in Claude Code, or the host agent's explicit skill invocation syntax.
- Contextual: "Analyze this repo", "Generate a study guide", "Explain this codebase", "Onboard me to this project".
