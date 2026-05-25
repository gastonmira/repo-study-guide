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

1. Call `mcp__code-review-graph__list_graph_stats_tool`. If it responds
   (even with `Nodes: 0` / `Last updated: never`), the MCP is available and
   **must be used** for exploration and analysis.
2. If the stats show `Nodes: 0` or stale data, call
   `mcp__code-review-graph__build_or_update_graph_tool` (idempotent;
   incremental updates run in <2s) before continuing.
3. Only if the tool errors out, is not registered, or returns a hard failure,
   fall back to the shell-based flow described inline in `SKILL.md`.

Skipping this preflight when the MCP is available is a **skill violation** —
the resulting study guide will be missing hub ranks, community structure, and
impact data that the graph provides and the template expects.

## Quality bar

**MCP-first when available** — if `code-review-graph` tools respond, they
MUST be used for structural exploration. Falling back to `Read`/`Grep`/`find`
without first attempting the graph is a skill violation. Use
`get_minimal_context_tool` / `get_review_context_tool` to pull only the
snippets the template actually needs.

When the MCP is available, the Hub rank column and Communities block in the
generated HTML must be populated from graph data (not inferred from folder
names).

## Tool catalog — when to use which

| Step in `SKILL.md`                          | Tool                                                | Purpose                                              |
| ------------------------------------------- | --------------------------------------------------- | ---------------------------------------------------- |
| Step 0 — preflight                          | `list_graph_stats_tool`                             | Probe availability, freshness, node/file count.      |
| Step 0 — preflight (if stale)               | `build_or_update_graph_tool`                        | Idempotent incremental rebuild.                      |
| Step 1 — size probe                         | `list_graph_stats_tool`                             | Use reported counts instead of `find \| wc -l`.      |
| Step 1 — architecture                       | `get_architecture_overview_tool`                    | High-level layout, modules, boundaries.              |
| Step 1 — large-repo subagent brief          | `get_hub_nodes_tool`, `list_communities_tool`       | Hubs by import-fan-in; logical modules.              |
| Step 2 — entry point                        | `list_flows_tool` → `get_flow_tool`                 | Find and trace the main execution flow.              |
| Step 2 — data flow                          | `get_flow_tool`                                     | One realistic input trace; only `Read` what it surfaces. |
| Step 2 — core logic (3–7 files)             | `get_hub_nodes_tool`, `list_communities_tool`       | Mandatory when MCP is available; feeds template.     |
| Step 2 — symbol / route lookup              | `semantic_search_nodes_tool`                        | Use before `rg`. Fall back to `rg` only on empty.    |
| Step 3b — snippets for the template         | `get_minimal_context_tool`, `get_review_context_tool` | Pull only the lines `{{MINIMAL_EXAMPLE}}` / `{{CORE_MODULES}}` need. |

## Final-checklist items related to the MCP

- If the MCP was available, at least `list_graph_stats_tool` + one of
  `get_architecture_overview_tool` / `get_hub_nodes_tool` /
  `list_communities_tool` were invoked during exploration.
- Hub rank column and Communities block in the HTML are populated from graph
  data when the MCP was available.
