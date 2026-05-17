---
name: repo-study-guide
description: Analyze any repository and generate a self-contained dark-themed HTML study guide plus a Mermaid architecture diagram. Use when the user asks to "analyze this repo", "generate a study guide", "explain this codebase", or wants a visual onboarding doc for a project.
---

# Repo Study Guide Skill

Universal instruction set to analyze any repository and produce a high-quality, self-contained HTML study guide plus an architecture diagram.

## When to use

Trigger this skill when the user:
- Opens an unfamiliar repo and wants a fast mental model.
- Asks for "study guide", "onboarding doc", "architecture overview", or "explain this codebase".
- Wants a visual artifact (HTML + Mermaid) instead of a chat-only explanation.

## Inputs

- **Target repo path** (default: current working directory).
- **Output directory** (default: `docs/` relative to the repo root; override if the user asks).

## Execution Steps

### 1. Exploration phase

Goal: build a mental model in the minimum number of reads.

- **Scan tree** — use `Bash` (`ls -la`, `find . -maxdepth 3 -type f`) to map the root and the obvious source folders (`src/`, `lib/`, `app/`, `pkg/`, `cmd/`, etc.).
- **Identity files** — read in parallel: `README.md`, `package.json`, `pyproject.toml`, `requirements.txt`, `Cargo.toml`, `go.mod`, `pom.xml`, `Gemfile`.
- **Type detection** — classify as one of: CLI, Web App, Library/SDK, ML/Data project, Monorepo, Infra/IaC.
- **For large repos (>500 files)** — delegate exploration to a subagent with `subagent_type: Explore` to avoid context bloat. Ask it for: entry points, top 10 files by import-fan-in, and the dependency graph at module level.

### 2. Analysis phase

- **Entry point** — locate `main.*`, `index.*`, `app.*`, `cli.*`, `__main__.py`, or the `"main"`/`"bin"` field in `package.json`.
- **Data flow** — trace one realistic input from entry → core logic → output. Note each module touched.
- **Core logic** — identify the 3–7 files that contain the business logic. Use `grep -r` for exported symbols, route definitions, command handlers, or model classes.
- **External surface** — APIs exposed, CLI commands, env vars, config files.

### Edge cases

- **Monorepos** — detect `workspaces` (`package.json`), `pnpm-workspace.yaml`, Turborepo, Nx, Cargo workspaces. Generate one study guide *per workspace package* under `docs/<package>/study_guide.html`, plus a root index.
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

## Final checklist (must pass before reporting done)

- [ ] `<output_dir>/study_guide.html` exists and opens in a browser without console errors.
- [ ] `<output_dir>/architecture.mmd` parses (sanity check: balanced brackets, no empty graph).
- [ ] All `{{PLACEHOLDERS}}` replaced — `grep -c '{{' study_guide.html` returns `0`.
- [ ] Sidebar TOC has working anchors for every `<section>`.
- [ ] Mermaid block renders (if CDN unreachable, fallback message is visible).

## Activation Trigger

- Manual: `/skill repo-study-guide`
- Contextual: "Analyze this repo", "Generate a study guide", "Explain this codebase", "Onboard me to this project".
