# Example output

This folder contains a sample run of the `repo-study-guide` skill against a small Python CLI repo, so you can preview the artifact before installing.

## Files

- `sample-output/study_guide.html` — the rendered guide (open in a browser).
- `sample-output/architecture.mmd` — the Mermaid source.

## How it was generated

```
# inside the target repo
> analyze this repo and generate a study guide
```

The skill ran the three phases (Exploration → Analysis → Artifact Generation) described in `../SKILL.md` and wrote both files to `docs/`. They were then copied here.

## Reproduce

To regenerate against your own repo:

```bash
cd /path/to/your/repo
# launch Claude Code, Codex, or another agent with the skill installed, then:
> analyze this repo and generate a study guide
```

In Codex, you can explicitly mention `$repo-study-guide`. In Claude Code, you can explicitly invoke `/skill repo-study-guide`.
