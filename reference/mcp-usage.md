# MCP Usage — `code-review-graph`

Support reference for `SKILL.md`. The main skill flow links here for the full
contract around the `code-review-graph` MCP: preflight, tool catalog, and
fallbacks. Read this when planning structural exploration or when the graph
errors out.

## Preflight (MANDATORY when available)

Before any `Read`, `Grep`, `Glob`, or `find` call for code exploration, you
MUST attempt the [`code-review-graph`](https://github.com/tirth8205/code-review-graph)
MCP. Reading project metadata (`README.md`, `package.json`,
`pyproject.toml`, etc.) is allowed in parallel — the graph does not cover
those.

1. Call `mcp__code-review-graph__list_graph_stats_tool` first. Do not use
   `get_minimal_context_tool` or other graph tools as the preflight probe.
   If stats responds, the MCP is available, but graph data still must pass the
   coverage gate before it is used as the source of truth for architecture,
   hubs, communities, or generated graph summaries.
2. If the stats show `Nodes: 0` or stale data, call
   `mcp__code-review-graph__build_or_update_graph_tool` (idempotent;
   incremental updates run in <2s) before continuing.
3. Run a shell file count and compare it with graph file coverage. Treat the
   graph as low coverage if it indexes no files, only a tiny subset of the repo,
   or mostly test files.
4. Only if the tool errors out, is not registered, returns a hard failure, or
   remains low coverage after update, fall back to the shell-based flow
   described inline in `SKILL.md`.

Skipping this preflight when the MCP is available is a **skill violation**.
Using low-coverage graph data as if it represented the whole repo is also a
skill violation; it can produce misleading hubs, communities, and architecture
summaries.

## Quality bar

**MCP-first when useful** — always try the graph preflight first, then use graph
tools only when coverage is representative. Falling back to `Read`/`Grep`/`find`
is correct when the MCP is unavailable, the graph is empty/stale, or graph
coverage is too narrow to describe the repo. Use `get_minimal_context_tool` /
`get_review_context_tool` only for targeted snippets after coverage is known.

When representative MCP graph data is available, the Hub rank column and graph
summary note in the generated HTML must be populated from graph data (not
inferred from folder names). The graph summary must define what nodes, edges,
communities, cohesion, and cross-community edges mean before listing raw
values. When graph coverage is low, omit graph-derived hub ranks and
`{{GRAPH_SUMMARY}}` rather than presenting incomplete data as architecture.

## Tool catalog — when to use which

| Step in `SKILL.md`                          | Tool                                                | Purpose                                              |
| ------------------------------------------- | --------------------------------------------------- | ---------------------------------------------------- |
| Step 0 — preflight                          | `list_graph_stats_tool`                             | Probe availability, freshness, node/file count.      |
| Step 0 — preflight (if stale)               | `build_or_update_graph_tool`                        | Idempotent incremental rebuild.                      |
| Step 1 — size probe                         | `list_graph_stats_tool` + shell count               | Compare graph coverage with repo file count.         |
| Step 1 — architecture                       | `get_architecture_overview_tool`                    | Use only when graph coverage is representative.      |
| Step 1 — large-repo subagent brief          | `get_hub_nodes_tool`, `list_communities_tool`       | Use only when graph coverage is representative.      |
| Step 2 — entry point                        | `list_flows_tool` → `get_flow_tool`                 | Find and trace the main execution flow.              |
| Step 2 — data flow                          | `get_flow_tool`                                     | One realistic input trace; only `Read` what it surfaces. |
| Step 2 — core logic (3–7 files)             | `get_hub_nodes_tool`, `list_communities_tool`       | Feeds template only when graph coverage is representative. |
| Step 2 — symbol / route lookup              | `semantic_search_nodes_tool`                        | Use before `rg`. Fall back to `rg` only on empty.    |
| Step 3b — snippets for the template         | `get_minimal_context_tool`, `get_review_context_tool` | Pull only the lines `{{MINIMAL_EXAMPLE}}` / `{{CORE_MODULES}}` need. |

## Final-checklist items related to the MCP

- `list_graph_stats_tool` was the first graph preflight call.
- Graph file coverage was compared with the repo file count before using graph
  architecture, hubs, communities, or summaries.
- Hub rank column and graph summary note in the HTML are populated only when
  representative graph data was available, with a plain-English explanation of
  the metrics.
