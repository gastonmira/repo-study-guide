#!/usr/bin/env bash
#
# pr-checks.sh — content & consistency checks for the repo-study-guide skill.
#
# Runs the same set of checks locally (before opening a PR) and in CI.
# It accumulates failures and reports them all at the end rather than
# aborting on the first one. Exit 0 = all green, exit 1 = at least one fail.
#
#   Usage:  bash scripts/pr-checks.sh
#
set -uo pipefail

# Always run from the repo root so relative paths resolve regardless of CWD.
cd "$(dirname "$0")/.."

EXPECTED_SLUG="repo-study-guide"
FAILED=0

pass() { printf '  \033[32m✓\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAILED=1; }
info() { printf '  \033[33m·\033[0m %s\n' "$1"; }
hdr()  { printf '\n\033[1m%s\033[0m\n' "$1"; }

# ---------------------------------------------------------------------------
# Check 1 — YAML / JSON parse cleanly
# ---------------------------------------------------------------------------
hdr "1. YAML / JSON validity"

# Pick a YAML parser. Try PyYAML (install if missing), then ruby's built-in
# YAML, then js-yaml via npx. Sets yaml_parse to a function taking a file path.
select_yaml_parser() {
  python3 -c "import yaml" 2>/dev/null || pip install --quiet pyyaml >/dev/null 2>&1
  if python3 -c "import yaml" 2>/dev/null; then
    yaml_parse() { python3 -c "import yaml,sys; yaml.safe_load(open(sys.argv[1]))" "$1"; }
    YAML_PARSER="PyYAML"; return 0
  fi
  if command -v ruby >/dev/null 2>&1 && ruby -ryaml -e '' 2>/dev/null; then
    yaml_parse() { ruby -ryaml -e 'YAML.safe_load(File.read(ARGV[0]))' "$1"; }
    YAML_PARSER="ruby"; return 0
  fi
  if command -v npx >/dev/null 2>&1; then
    yaml_parse() { npx --yes js-yaml "$1" >/dev/null; }
    YAML_PARSER="js-yaml"; return 0
  fi
  return 1
}

if select_yaml_parser; then
  info "YAML parser: $YAML_PARSER"
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    if yaml_parse "$f" >/dev/null 2>&1; then
      pass "valid YAML: $f"
    else
      fail "invalid YAML: $f"
    fi
  done < <(git ls-files '*.yaml' '*.yml')
else
  fail "no YAML parser available (tried PyYAML, ruby, js-yaml)"
fi

while IFS= read -r f; do
  [ -z "$f" ] && continue
  if python3 -m json.tool "$f" >/dev/null 2>&1; then
    pass "valid JSON: $f"
  else
    fail "invalid JSON: $f"
  fi
done < <(git ls-files '*.json')

# ---------------------------------------------------------------------------
# Check 2 — SKILL.md frontmatter has name + description, name == slug
# ---------------------------------------------------------------------------
hdr "2. SKILL.md frontmatter"

if [ ! -f SKILL.md ]; then
  fail "SKILL.md not found"
else
  # Extract the frontmatter block between the first two '---' lines.
  fm="$(awk 'NR==1 && $0=="---"{f=1;next} f && $0=="---"{exit} f{print}' SKILL.md)"
  if [ -z "$fm" ]; then
    fail "SKILL.md has no frontmatter block"
  else
    skill_name="$(printf '%s\n' "$fm" | sed -n 's/^name:[[:space:]]*//p' | head -n1)"
    has_desc="$(printf '%s\n' "$fm" | grep -c '^description:[[:space:]]*..*')"
    if [ -n "$skill_name" ]; then pass "name present: $skill_name"; else fail "frontmatter missing 'name'"; fi
    if [ "$has_desc" -ge 1 ]; then pass "description present"; else fail "frontmatter missing 'description'"; fi
    if [ "$skill_name" = "$EXPECTED_SLUG" ]; then
      pass "name matches expected slug ($EXPECTED_SLUG)"
    else
      fail "name '$skill_name' != expected slug '$EXPECTED_SLUG'"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Check 3 — slug consistency: $<slug> in openai.yaml default_prompt
# ---------------------------------------------------------------------------
hdr "3. Slug consistency across files"

YAML=agents/openai.yaml
if [ ! -f "$YAML" ]; then
  fail "$YAML not found"
elif grep -q "\$${EXPECTED_SLUG}\b" "$YAML"; then
  pass "$YAML references \$${EXPECTED_SLUG}"
else
  fail "$YAML does not reference \$${EXPECTED_SLUG} (default_prompt drift?)"
fi

# ---------------------------------------------------------------------------
# Check 4 — relative Markdown links point to existing files
# ---------------------------------------------------------------------------
hdr "4. Markdown internal links"

broken=0
while IFS= read -r md; do
  [ -z "$md" ] && continue
  dir="$(dirname "$md")"
  # Pull link targets from [text](target); one per line.
  targets="$(grep -oE '\]\([^)]+\)' "$md" | sed -E 's/^\]\(//; s/\)$//')"
  while IFS= read -r tgt; do
    [ -z "$tgt" ] && continue
    case "$tgt" in
      http://*|https://*|mailto:*|\#*|"") continue ;;
    esac
    # Strip any #anchor and ?query suffix, then resolve against the file's dir.
    path="${tgt%%#*}"; path="${path%%\?*}"
    [ -z "$path" ] && continue
    if [ ! -e "$dir/$path" ]; then
      fail "broken link in $md -> $tgt"
      broken=1
    fi
  done <<< "$targets"
done < <(git ls-files '*.md')
[ "$broken" -eq 0 ] && pass "all relative Markdown links resolve"

# ---------------------------------------------------------------------------
# Check 5 — HTML offline-safety (inline <style> + mermaid fallback present)
# ---------------------------------------------------------------------------
hdr "5. HTML offline-safety"

check_html() {
  local f="$1"
  if [ ! -f "$f" ]; then fail "$f not found"; return; fi
  local ok=1
  grep -q '<style' "$f"                      || { fail "$f: no inline <style> block"; ok=0; }
  grep -q 'Mermaid unavailable offline' "$f" || { fail "$f: missing mermaid offline fallback"; ok=0; }
  [ "$ok" -eq 1 ] && pass "$f opens offline (inline styles + mermaid fallback)"
}
check_html templates/study_guide_template.html
check_html examples/sample-output/study_guide.html

# ---------------------------------------------------------------------------
# Check 6 — Mermaid diagram parses (mmdc)
# ---------------------------------------------------------------------------
hdr "6. Mermaid diagram validity"

MMD=examples/sample-output/architecture.mmd
if [ ! -f "$MMD" ]; then
  fail "$MMD not found"
elif ! command -v npx >/dev/null 2>&1; then
  if [ "${CI:-}" = "true" ]; then
    fail "npx not available in CI — cannot validate Mermaid"
  else
    info "npx not available — skipping Mermaid validation locally"
  fi
else
  # CI runners can't use Chromium's sandbox, so render with --no-sandbox.
  # Harmless locally. Passed via a puppeteer config file (-p).
  PCFG="$(mktemp -t puppeteer.XXXXXX.json)"
  printf '{ "args": ["--no-sandbox", "--disable-setuid-sandbox"] }' > "$PCFG"
  if npx --yes @mermaid-js/mermaid-cli -p "$PCFG" -i "$MMD" -o /tmp/arch.svg >/tmp/mmdc.log 2>&1; then
    pass "$MMD renders cleanly"
  else
    # Only skip when Chromium genuinely cannot be *launched* (not installed).
    # A real syntax error renders inside a running browser, so we must NOT
    # treat generic puppeteer/browser mentions as an environment problem.
    if [ "${CI:-}" != "true" ] && grep -qiE 'Failed to launch|Could not find (Chrome|Chromium)|Browser was not found|browsers install' /tmp/mmdc.log; then
      info "Chromium not installed locally — skipping Mermaid validation (will run in CI)"
    else
      fail "$MMD failed to render (see /tmp/mmdc.log)"
    fi
  fi
fi

# ---------------------------------------------------------------------------
hdr "Result"
if [ "$FAILED" -eq 0 ]; then
  printf '  \033[32mAll checks passed.\033[0m\n'
  exit 0
else
  printf '  \033[31mSome checks failed.\033[0m\n'
  exit 1
fi
