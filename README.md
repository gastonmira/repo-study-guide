# repo-study-guide

A Claude Code skill that analyzes any repository and generates a self-contained, dark-themed HTML study guide with an architecture diagram.

Drop it on an unfamiliar codebase and get a one-page visual onboarding doc: overview, purpose, data flow, core modules, minimal runnable example, and a Mermaid architecture diagram — all in a single HTML file.

## What it produces

```
docs/
├── study_guide.html      # self-contained, dark theme, sidebar TOC, scrollspy
└── architecture.mmd      # Mermaid source of the architecture diagram
```

The HTML embeds Mermaid + highlight.js from CDN with graceful offline degradation.

## Installation

### As a Claude Code skill (recommended)

```bash
git clone https://github.com/gastonmira/repo-study-guide.git ~/.claude/skills/repo-study-guide
```

Then in any Claude Code session, the skill auto-loads. Trigger it with:

```
/skill repo-study-guide
```

Or just ask naturally: *"analyze this repo"*, *"generate a study guide"*, *"explain this codebase"*.

### As a reference for other agents (Cursor, Aider, Hermes, custom)

Copy `SKILL.md` into your agent's instruction set or system prompt. The template lives in `templates/study_guide_template.html` — point your agent at it.

## Usage

From inside any repo:

```
> analyze this repo and generate a study guide
```

The skill will:

1. Scan the file tree and identity files (`README`, `package.json`, etc.).
2. Detect project type (CLI / Web App / Library / ML / Monorepo).
3. Trace the entry point and data flow.
4. Generate `docs/architecture.mmd` and `docs/study_guide.html`.

Open the HTML in any browser — no build step.

## Output sections

| Section | Content |
|---|---|
| Overview | What the project does (2–3 sentences) |
| Purpose | Why it exists / problem it solves |
| Architecture | Rendered Mermaid diagram |
| Step-by-Step | Ordered data-flow trace |
| Core Modules | Table of key files + 1-sentence role |
| Minimal Example | Smallest runnable snippet |
| Local Setup | Install + run commands |

## Customization

Edit `templates/study_guide_template.html` to change theme, layout, or sections. Placeholders use `{{SNAKE_CASE}}` syntax — see `SKILL.md` for the full list.

To change the output directory, ask the skill explicitly: *"generate the study guide into `wiki/` instead of `docs/`"*.

## Edge cases handled

- **Monorepos** — generates one guide per workspace under `docs/<package>/`.
- **No README** — infers purpose from package metadata; marks as `(inferred)`.
- **Large repos (>500 files)** — delegates exploration to an `Explore` subagent.
- **Empty / scaffolding repos** — produces a minimal guide with next-step suggestions.

## Examples

See [`examples/`](examples/) for a sample output generated against a real repo.

## Contributing

Issues and PRs welcome. Particularly useful contributions:

- New template themes (light, sepia, print-friendly).
- Better project-type detection heuristics.
- Adapters for other agent frameworks.

## License

MIT — see [LICENSE](LICENSE).
