# Edge Cases

Support reference for `SKILL.md`. Read when the target repo does not fit the
happy path.

## Monorepos

Detect `workspaces` (`package.json`), `pnpm-workspace.yaml`, Turborepo, Nx,
Cargo workspaces. When the graph is available, `list_communities_tool` often
surfaces logical packages as distinct communities — cross-reference with
workspace config.

Generate one study guide *per workspace package* under
`docs/<package>/study_guide.html`, plus a root index.

## No README

Derive purpose from package metadata, top-level comments, and folder names.
Mark the "Purpose" section as `(inferred)`.

## Empty / scaffolding only

Produce a minimal guide noting the repo is a scaffold; suggest next steps
instead of forcing analysis.

## Unknown language

Fall back to file-extension stats and any build configs found.
