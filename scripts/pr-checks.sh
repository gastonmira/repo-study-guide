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
JS_YAML_BIN="./node_modules/.bin/js-yaml"
MMDC_BIN="./node_modules/.bin/mmdc"
MERMAID_TIMEOUT_SECONDS=90

pass() { printf '  \033[32m✓\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAILED=1; }
info() { printf '  \033[33m·\033[0m %s\n' "$1"; }
hdr()  { printf '\n\033[1m%s\033[0m\n' "$1"; }

# ---------------------------------------------------------------------------
# Check 1 — YAML / JSON parse cleanly
# ---------------------------------------------------------------------------
hdr "1. YAML / JSON validity"

# Pick a YAML parser without installing anything at runtime. Prefer the locked
# local js-yaml dependency, then fall back to already-installed system parsers.
select_yaml_parser() {
  if [ -x "$JS_YAML_BIN" ]; then
    yaml_parse() { "$JS_YAML_BIN" "$1" >/dev/null; }
    YAML_PARSER="js-yaml"; return 0
  fi
  if python3 -c "import yaml" 2>/dev/null; then
    yaml_parse() { python3 -c "import yaml,sys; yaml.safe_load(open(sys.argv[1]))" "$1"; }
    YAML_PARSER="PyYAML"; return 0
  fi
  if command -v ruby >/dev/null 2>&1 && ruby -ryaml -e '' 2>/dev/null; then
    yaml_parse() { ruby -ryaml -e 'YAML.safe_load(File.read(ARGV[0]))' "$1"; }
    YAML_PARSER="ruby"; return 0
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
  fail "no YAML parser available (run 'npm ci' or install PyYAML/ruby YAML)"
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
# Check 6 — Generated HTML structure
# ---------------------------------------------------------------------------
hdr "6. Generated HTML structure"

require_literal() {
  local f="$1" literal="$2" label="$3"
  if grep -Fq "$literal" "$f"; then
    pass "$label"
  else
    fail "$f: missing $label"
  fi
}

require_section() {
  local f="$1" id="$2"
  require_literal "$f" "<section id=\"$id\">" "section #$id"
}

check_template_placeholders() {
  local f="templates/study_guide_template.html"
  local placeholders=(
    PROJECT_NAME PROJECT_TYPE OVERVIEW GRAPH_SUMMARY WHAT_CHANGED PURPOSE
    STEP_BY_STEP CORE_MODULES_HEADER CORE_MODULES READING_ORDER FIRST_TASKS
    MINIMAL_EXAMPLE LOCAL_SETUP MERMAID_DIAGRAM ARCHITECTURE_EXPLANATION
    GENERATED_AT COMMIT_HASH
  )
  local missing=0
  for ph in "${placeholders[@]}"; do
    if grep -Fq "{{$ph}}" "$f"; then
      pass "$f contains {{$ph}}"
    else
      fail "$f: missing {{$ph}}"
      missing=1
    fi
  done
  [ "$missing" -eq 0 ] && pass "$f contains all required placeholders"
}

check_generated_html() {
  local f="examples/sample-output/study_guide.html"
  if [ ! -f "$f" ]; then fail "$f not found"; return; fi

  if grep -Fq '{{' "$f"; then
    fail "$f: contains unreplaced placeholder"
  else
    pass "$f has no unreplaced placeholders"
  fi

  grep -Eq '<meta name="repo-study-guide-commit" content="[^"]+">' "$f" \
    && pass "$f has repo-study-guide-commit meta" \
    || fail "$f: missing populated repo-study-guide-commit meta"
  grep -Eq '<meta name="repo-study-guide-generated" content="[^"]+">' "$f" \
    && pass "$f has repo-study-guide-generated meta" \
    || fail "$f: missing populated repo-study-guide-generated meta"

  require_literal "$f" '<ul id="toc"></ul>' "TOC container"
  require_literal "$f" '<div class="mermaid">' "Mermaid block"
  require_literal "$f" 'class="diagram-shell"' "diagram shell"
  require_literal "$f" 'data-diagram-zoom=' "diagram zoom controls"
  require_literal "$f" '<thead><tr><th>File</th><th>Role</th></tr></thead>' "2-column Core Modules header"

  for id in overview purpose architecture step-by-step core-modules onboarding-path minimal-example local-setup; do
    require_section "$f" "$id"
  done

  if grep -Eqi 'javascript:|<[[:alnum:]][^>]+[[:space:]]on[a-z]+[[:space:]]*=' "$f"; then
    fail "$f: contains javascript: URL or inline event handler"
  else
    pass "$f has no javascript: URLs or inline event handlers"
  fi

  if npm run validate:html >/tmp/validate-html.log 2>&1; then
    pass "$f passes HTML safety allowlist"
  else
    fail "$f failed HTML safety allowlist (see /tmp/validate-html.log)"
  fi
}

check_template_placeholders
check_generated_html

# ---------------------------------------------------------------------------
# Check 7 — Mermaid diagram parses (mmdc)
# ---------------------------------------------------------------------------
hdr "7. Mermaid diagram validity"

MMD=examples/sample-output/architecture.mmd
if [ ! -f "$MMD" ]; then
  fail "$MMD not found"
elif [ ! -x "$MMDC_BIN" ]; then
  fail "Mermaid CLI not found at $MMDC_BIN (run 'npm ci')"
elif ! command -v timeout >/dev/null 2>&1; then
  fail "timeout command not available — cannot enforce Mermaid render limit"
else
  # CI runners can't use Chromium's sandbox, so render with --no-sandbox.
  # Harmless locally. Passed via a puppeteer config file (-p).
  PCFG="$(mktemp -t puppeteer.XXXXXX.json)"
  printf '{ "args": ["--no-sandbox", "--disable-setuid-sandbox"] }' > "$PCFG"
  if timeout "${MERMAID_TIMEOUT_SECONDS}s" "$MMDC_BIN" -p "$PCFG" -i "$MMD" -o /tmp/arch.svg >/tmp/mmdc.log 2>&1; then
    pass "$MMD renders cleanly"
  else
    status=$?
    # Only skip when Chromium genuinely cannot be *launched* (not installed).
    # A real syntax error renders inside a running browser, so we must NOT
    # treat generic puppeteer/browser mentions as an environment problem.
    if [ "$status" -eq 124 ]; then
      fail "$MMD Mermaid render timed out after ${MERMAID_TIMEOUT_SECONDS}s"
    elif [ "${CI:-}" != "true" ] && grep -qiE 'Failed to launch|Could not find (Chrome|Chromium)|Browser was not found|browsers install' /tmp/mmdc.log; then
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
