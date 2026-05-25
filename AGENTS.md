<!-- code-review-graph MCP tools -->
## MCP Tools: code-review-graph

This project can use the `code-review-graph` MCP for code exploration and
review.

Before broad file search or code reading, first try the available
`code-review-graph` tools, starting with graph stats or change detection
depending on the task.

Use graph tools when they are available and return useful data. If the MCP is
unavailable, the graph is empty/stale, or the needed tool is not exposed by the
current client, fall back to normal repo exploration with `rg`, file reads, and
git commands.

Do not fail the task solely because the graph is empty or a named graph tool is
unavailable. Use the best available fallback and mention that fallback in the
final response.

### Workflow

1. Check graph availability before broad exploration.
2. For code review, prefer change-aware graph tools when available.
3. For exploration, prefer graph summaries or relationships when available.
4. Fall back to `rg`, file reads, and Git commands whenever the graph does not
   cover the task.
