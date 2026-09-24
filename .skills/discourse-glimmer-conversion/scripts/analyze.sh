#!/usr/bin/env bash
# Pre-flight report for converting one classic component to Glimmer.
#
# Usage: .skills/discourse-glimmer-conversion/scripts/analyze.sh path/to/component.gjs
#   CORE_DIR     Discourse core checkout used for call-site scans when the target lives in
#                another repo (default: the checkout this script is part of).
#   ALL_THE_DIR  Root of the external plugin/theme checkouts (default ~/discourse/all-the).
#
# No `-e`: empty grep results are normal here and must not abort the report.
set -uo pipefail

file="${1:-}"
if [[ -z "$file" || ! -f "$file" ]]; then
  echo "usage: $0 path/to/component.(js|gjs)" >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
core_dir="${CORE_DIR:-$(git -C "$script_dir" rev-parse --show-toplevel)}"
target_repo="$(git -C "$(dirname "$file")" rev-parse --show-toplevel 2>/dev/null || dirname "$file")"
file="$(cd "$(dirname "$file")" && pwd)/$(basename "$file")"
rel="${file#"$target_repo"/}"
rel="${rel%.*}"
in_core=0
[[ "$target_repo" == "$core_dir" ]] && in_core=1

all_the="${ALL_THE_DIR:-$HOME/discourse/all-the}"
external_dirs=()
for d in all-the-plugins/official all-the-plugins/third-party all-the-themes/official \
         all-the-themes/third-party all-the-custom-plugins/plugins all-the-custom-themes/themes; do
  [[ -d "$all_the/$d" ]] && external_dirs+=("$all_the/$d")
done

# Module path as consumers import it, and the resolver name used by modifyClass / {{component}}.
kind="core"
case "$rel" in
  frontend/discourse/app/*)        import_path="discourse/${rel#frontend/discourse/app/}" ;;
  frontend/discourse/admin/*)      import_path="discourse/admin/${rel#frontend/discourse/admin/}" ;;
  frontend/discourse/select-kit/*) import_path="discourse/select-kit/${rel#frontend/discourse/select-kit/}" ;;
  frontend/discourse/float-kit/*)  import_path="discourse/float-kit/${rel#frontend/discourse/float-kit/}" ;;
  plugins/*/admin/assets/javascripts/*)
    plugin="${rel#plugins/}"; plugin="${plugin%%/*}"
    import_path="discourse/plugins/$plugin/${rel#plugins/*/admin/assets/javascripts/}"; kind="plugin" ;;
  plugins/*/assets/javascripts/*)
    plugin="${rel#plugins/}"; plugin="${plugin%%/*}"
    import_path="discourse/plugins/$plugin/${rel#plugins/*/assets/javascripts/}"; kind="plugin" ;;
  admin/assets/javascripts/*)      import_path="discourse/plugins/$(basename "$target_repo")/${rel#admin/assets/javascripts/}"; kind="external-plugin" ;;
  assets/javascripts/*)            import_path="discourse/plugins/$(basename "$target_repo")/${rel#assets/javascripts/}"; kind="external-plugin" ;;
  javascripts/discourse/*)         import_path="(theme module; imported only within the theme)"; kind="external-theme" ;;
  *)                               import_path="$rel"; kind="unknown" ;;
esac
resolver_name="${rel#*/components/}"
[[ "$resolver_name" == "$rel" ]] && resolver_name="${rel##*/}"
class_name="$(grep -oE 'export default class [A-Za-z0-9_]+' "$file" | awk '{print $4}' || true)"
base_name="$(basename "$rel")"

# Split at <template> so class-level greps ignore the template and vice versa.
class_part="$(awk '/<template>/{exit} {print}' "$file")"
template_part="$(awk 'f{print} /<template>/{f=1}' "$file")"

# Where consumers can live.
src_dirs=()
if [[ $in_core -eq 1 ]]; then
  src_dirs+=(frontend/discourse/app frontend/discourse/admin frontend/discourse/select-kit frontend/discourse/float-kit frontend/discourse/tests)
  for p in plugins/*/assets/javascripts plugins/*/admin/assets/javascripts plugins/*/test/javascripts; do [[ -d "$p" ]] && src_dirs+=("$p"); done
else
  for p in assets/javascripts admin/assets/javascripts test/javascripts javascripts; do [[ -d "$target_repo/$p" ]] && src_dirs+=("$target_repo/$p"); done
  for p in frontend/discourse/app frontend/discourse/admin frontend/discourse/tests; do [[ -d "$core_dir/$p" ]] && src_dirs+=("$core_dir/$p"); done
  for p in "$core_dir"/plugins/*/assets/javascripts "$core_dir"/plugins/*/admin/assets/javascripts; do [[ -d "$p" ]] && src_dirs+=("$p"); done
fi
cd "$core_dir"
includes=(--include='*.gjs' --include='*.gts' --include='*.js' --include='*.ts' --include='*.hbs')
excludes=(--exclude-dir=node_modules --exclude-dir=dist --exclude-dir=.git --exclude-dir=tmp --exclude-dir=public)

hr() { printf '\n== %s\n' "$1"; }
prefix() { awk -v p="$1" '{print "  " p $0}'; }
strip_root() { sed -e "s#^$core_dir/##" -e "s#^$target_repo/##" -e "s#^$all_the/##"; }

echo "component : $rel (${kind}, repo $target_repo)"
echo "class     : ${class_name:-<none: template-only or non-class export>}"
echo "import    : $import_path"
echo "resolver  : component:$resolver_name"
[[ $in_core -eq 0 ]] && echo "note      : target is outside core; call sites are scanned in the target repo and in $core_dir"

hr "classic features (line: match)"
code_only() { grep -vE '^[0-9]+:\s*(//|\*|/\*)' | grep -vE '^[0-9]+:\s*import\b'; }
features=(
  'from "@ember/component"' '@ember-decorators/component' '@ember-decorators/object' 'ember/no-classic-components'
  '@tagName\(' '@classNames\(' '@classNameBindings\(' '@attributeBindings\(' '\belementId\b' '\bariaRole\b'
  '\bpositionalParams\b' '\blayoutName\b' '\blayout\s*=' '\bisVisible\b'
  '@computed\(' '@discourseComputed\b' '@observes\(' '@on\(' '\bobserver\(' '@readOnly\b' '\bdependentKeyCompat\b'
  '@(alias|reads|or|and|not|equal|gt|gte|lt|lte|empty|notEmpty|bool|match|sort|uniq|filter|map)\('
  'this\.set\(' 'this\.get\(' '\bsetProperties\(' '\btoggleProperty\(' '\bincrementProperty\(' '\bnotifyPropertyChange\(' '\baddObserver\(' '\bremoveObserver\(' '\bset\(this\b'
  '^\s*init\(\)' '\bdidInsertElement\b' '\bdidReceiveAttrs\b' '\bdidUpdateAttrs\b' '\bdidRender\b' '\bdidUpdate\(' '\bwillRender\b' '\bwillUpdate\b' '\bwillClearRender\b'
  '\bwillInsertElement\b' '\bwillDestroyElement\b' '\bdidDestroyElement\b' '\bwillDestroy\(' '\brerender\('
  'this\.element\b' 'this\.\$\(' 'this\.attrs\b' '\bsendAction\(' 'this\.send\(' '\bactions\s*[:=]' 'this\.actions\b' '\bparentView\b'
  '^\s*(click|doubleClick|keyDown|keyUp|keyPress|mouseEnter|mouseLeave|mouseMove|mouseDown|mouseUp|focusIn|focusOut|change|input|submit|dragOver|dragStart|drop|touchStart|touchEnd|scroll|paste)\([a-zA-Z]*\)\s*\{'
  '\.extend\(' '\bMixin\b' 'appEvents\.(on|off)\(' 'messageBus\.(subscribe|unsubscribe)' '\baddEventListener\(' '\bschedule\(' '\bscheduleOnce\(' '\bnext\(' '\bdiscourseLater\(' '\b[dD]ebounce\b' '@bind\b' '@afterRender\b' '\bisDestroying\b' '\bjquery\b' '\$\('
)
for f in "${features[@]}"; do
  printf '%s\n' "$class_part" | grep -nE -- "$f" | code_only | prefix "[$f] " || true
done | awk '!seen[$0]++'
for f in '\{\{yield' 'has-block' 'hasBlock' '\(mut ' '\{\{action ' '\(action ' '<(Input|Textarea|DTextField|DTextarea|TextField|DDatePicker|DateInput|DDateInput|PreferenceCheckbox|DRadioButton|RadioButton|TagChooser|ChatChannelChooser)\b' '@value=\{\{this\.' '@checked=\{\{this\.' '@selection=\{\{this\.' '\{\{input ' '\breadonly\b' '\bunbound\b' '\{\{component ' '@tagName=' '@classNames=' '@class=' '@id=' '@elementId=' 'this\.element\b'; do
  printf '%s\n' "$template_part" | grep -nE -- "$f" | prefix "[template: $f] " || true
done | awk '!seen[$0]++'

hr "declared members (fields, getters, methods, services; class-body indentation only)"
# Prettier puts class members at exactly two spaces; deeper indentation is method bodies.
member_re='^ {2}(@[a-zA-Z]+(\([^)]*\))?\s+)*(static\s+)?(get\s+|set\s+|async\s+|#)?[A-Za-z_#][A-Za-z0-9_]*\s*(=[^=]|\(|;)'
members="$(printf '%s\n' "$class_part" | grep -nE "$member_re" | grep -vE '^[0-9]+: {2}(if|for|while|return|switch|const|let|var|super|this|await|new|throw|try|catch|else|import|export)\b' || true)"
if [[ -n "$members" ]]; then
  printf '%s\n' "$members" | prefix ""
else
  echo "  (none: expect a template-only component as the result; a class stays only for external extends/modifyClass consumers)"
fi

declared="$(printf '%s\n' "$members" | sed -E 's/^[0-9]+://; s/[[:space:]]*(=[^=]|\(|;).*$//' | awk '{print $NF}' | sed 's/^#//' | sort -u)"
reads="$(grep -oE 'this\.[A-Za-z_][A-Za-z0-9_]*' "$file" | sed 's/^this\.//' | sort -u)"
written="$( { grep -oE 'this\.set\("[A-Za-z_][A-Za-z0-9_]*"' "$file" | sed -E 's/this\.set\("//; s/"$//';
              grep -oE 'set\(this, "[A-Za-z_][A-Za-z0-9_]*"' "$file" | sed -E 's/set\(this, "//; s/"$//';
              grep -oE 'this\.(toggleProperty|incrementProperty|decrementProperty)\("[A-Za-z_][A-Za-z0-9_]*"' "$file" | sed -E 's/.*\("//; s/"$//';
              grep -oE 'this\.[A-Za-z_][A-Za-z0-9_]*\s*(=[^=]|\+=|-=|\+\+|--)' "$file" | sed -E 's/^this\.//; s/[[:space:]]*(=|\+|-).*$//';
              grep -oE '\(mut this\.[A-Za-z_][A-Za-z0-9_]*' "$file" | sed 's/(mut this\.//'; } | sort -u)"
injected='appEvents|pmTopicTrackingState|store|site|searchService|session|messageBus|siteSettings|topicTrackingState|keyValueStore|currentUser|capabilities'
builtin="^(args|element|elementId|isDestroying|isDestroyed|set|get|setProperties|toggleProperty|incrementProperty|decrementProperty|send|sendAction|actions|_super|rerender|notifyPropertyChange|attrs|parentView|childViews|register|willDestroy|didInsertElement|willDestroyElement|didReceiveAttrs|didUpdateAttrs|didUpdate|didRender|init|constructor|toString|tagName|classNames|classNameBindings|attributeBindings|addObserver|removeObserver|${injected})$"

hr "candidate args: this.<name> read but never declared or assigned (confirm against call sites)"
comm -23 <(printf '%s\n' "$reads") <(printf '%s\n' "$declared") | grep -vE "$builtin" | grep -vxF -f <(printf '%s\n' "$written"; echo "__none__") | prefix "" || true
echo "  -- own state assigned but never declared (needs a field; @tracked when the template, a getter it reads, a modifier, or a helperFn must react):"
comm -23 <(printf '%s\n' "$written") <(printf '%s\n' "$declared") | grep -vE "$builtin" | grep -v '\.' | prefix "" || true
injections="$(grep -oE "this\.(${injected})\b" "$file" | sed 's/this\.//' | sort -u | tr '\n' ' ')"
declared_services="$(printf '%s\n' "$class_part" | grep -oE '@service(\("[^"]+"\))?\s+[A-Za-z_][A-Za-z0-9_]*' | awk '{print $NF}' | sort -u | tr '\n' ' ')"
echo "  (implicit injections read: ${injections:-none}; declared with @service: ${declared_services:-none})"

hr "the component itself passed to a function or registry (the receiver changes on conversion)"
safe_this='(getOwner|setOwner|guidFor|registerDestructor|associateDestroyableChild|isDestroying|isDestroyed|destroy|set|get|setProperties|getProperties|addObserver|removeObserver|notifyPropertyChange|bind)'
grep -nE '[A-Za-z_][A-Za-z0-9_.]*\(\s*this\s*[,)]|\bthis\.[A-Za-z_][A-Za-z0-9_]*\.(call|apply|bind)\(' "$file" \
  | grep -vE "\b${safe_this}\(\s*this\s*[,)]" | prefix "" || true
echo "  -- a helper handed \`this\` may call \`.get(key)\` or \`fn.apply(context)\` on it; a Glimmer"
echo "     component has no \`get\` and keeps its args under \`this.args\`. Read the callee before converting."

hr "writes to this.<name> (two-way binding candidates when <name> is an arg; a.b paths are writes into an arg's object)"
grep -nE 'this\.(set|setProperties|toggleProperty|incrementProperty|decrementProperty)\(|^\s*set\(this,|^\s*setProperties\(this,|^\s+this\.[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)*\s*(=[^=]|\+=|-=|\+\+|--)|\(mut this\.|\(mut @' "$file" | prefix "" || true

hr "template reads of @args (excluding args passed to children)"
printf '%s\n' "$template_part" | grep -oE '@[A-Za-z_][A-Za-z0-9_.-]*([^=A-Za-z0-9_.-]|$)' | sed -E 's/[^A-Za-z0-9_.-]$//' | sort | uniq -c | sort -rn | prefix "" || true
echo "  -- this.* reads in template"
printf '%s\n' "$template_part" | grep -oE 'this\.[A-Za-z_][A-Za-z0-9_]*' | sort | uniq -c | sort -rn | prefix "" || true

hr "call sites (angle-bracket, absolute and relative imports, string lookups)"
site_re="from \"${import_path}\"|from \"\.{1,2}/([^\"]*/)?${base_name}\"|component:${resolver_name}([^A-Za-z0-9/_-]|\$)|\{\{component \"${resolver_name}\"|\{\{${resolver_name}[ }]"
[[ -n "$class_name" ]] && site_re="<${class_name}([^A-Za-z0-9_]|\$)|<\/${class_name}>|${site_re}"
call_sites="$(grep -rnE "${includes[@]}" "${excludes[@]}" -- "$site_re" "${src_dirs[@]}" 2>/dev/null | grep -v "^$file:" | grep -v "^${rel}\.[a-z]*:" || true)"
printf '%s\n' "$call_sites" | grep -v '^$' | strip_root | prefix "" || true
# A component nothing renders is dead code: delete it instead of converting it. Connectors are
# the exception, since the plugin-outlet system renders them by directory path.
if [[ -z "$call_sites" && "$rel" != */connectors/* ]]; then
  echo "  !! NO CALL SITES. Not a connector, so this may be DEAD CODE — verify before converting:"
  echo "     the external-checkout section below must also be empty, and check a theme cannot"
  echo "     reach it (grep the all-the checkouts for '<${class_name:-?}' and 'component:${resolver_name}')."
  echo "     If nothing renders it, propose deleting the file rather than converting it."
fi

hr "class fields that call sites also pass as args (classic lets the arg win; Glimmer needs this.args.x ?? default)"
fields="$(printf '%s\n' "$members" | sed -E 's/^[0-9]+://' | grep -E '^ {2}(@tracked\s+)?[A-Za-z_][A-Za-z0-9_]*\s*=[^=]' | sed -E 's/^ {2}(@tracked[[:space:]]+)?//; s/[[:space:]]*=.*$//' | sort -u | tr '\n' '|' | sed 's/|$//')"
if [[ -n "$fields" && -n "$class_name" ]]; then
  callsite_files="$(grep -rlE "${includes[@]}" "${excludes[@]}" -- "<${class_name}([^A-Za-z0-9_]|\$)" "${src_dirs[@]}" 2>/dev/null | grep -v "^$file$" || true)"
  for cf in $callsite_files; do
    # Capture each <ClassName ...> opening tag, which may span lines and may share its first line with other markup.
    awk -v c="$class_name" -v f="$cf" '
      {
        line = $0
        if (!capturing) {
          i = index(line, "<" c)
          if (i > 0) {
            rest = substr(line, i + length(c) + 1)
            if (rest ~ /^[^A-Za-z0-9_]/ || rest == "") { capturing = 1; line = substr(line, i); tail = rest }
          }
        } else { tail = line }
        if (capturing) {
          print f ":" NR ":" line
          if (tail ~ />/) capturing = 0
        }
      }' "$cf"
  done | grep -E "@(${fields})=" | strip_root | prefix "" || true
  echo "  (fields checked: $(echo "$fields" | tr '|' ' '))"
fi

hr "subclasses (extends / .extend)"
if [[ -n "$class_name" ]]; then
  grep -rnE "${includes[@]}" "${excludes[@]}" -- "extends ${class_name}([^A-Za-z0-9_]|\$)|${class_name}\.extend\(" "${src_dirs[@]}" 2>/dev/null | grep -v "^$file:" | strip_root | prefix "" || true
fi

hr "modifyClass targets (core, bundled plugins, target repo)"
grep -rnE "${includes[@]}" "${excludes[@]}" -- "modifyClass\(\s*[\"'\`]component:${resolver_name}[\"'\`]" "${src_dirs[@]}" 2>/dev/null | strip_root | prefix "" || true

if [[ ${#external_dirs[@]} -gt 0 ]]; then
  hr "external checkouts under $all_the (flag, do not edit; single pass, about ten seconds)"
  ext_re="modifyClass\(\s*[\"'\`]component:${resolver_name}[\"'\`]|\{\{component \"${resolver_name}\""
  [[ "$kind" == "core" || "$kind" == "plugin" ]] && ext_re="${ext_re}|\"${import_path}\""
  [[ -n "$class_name" ]] && ext_re="${ext_re}|<${class_name}([^A-Za-z0-9_]|\$)|extends ${class_name}([^A-Za-z0-9_]|\$)|${class_name}\.extend\("
  grep -rnE "${includes[@]}" "${excludes[@]}" -- "$ext_re" "${external_dirs[@]}" 2>/dev/null | grep -v "^$file:" | strip_root | prefix "" || true
else
  hr "external checkouts not found at $all_the (set ALL_THE_DIR to override)"
fi

hr "tests and specs (by resolver/class name, then by selectors the component renders)"
test_dirs=()
if [[ $in_core -eq 1 ]]; then
  test_dirs+=(frontend/discourse/tests spec/system)
  for p in plugins/*/test/javascripts plugins/*/spec/system; do [[ -d "$p" ]] && test_dirs+=("$p"); done
else
  for p in test/javascripts spec; do [[ -d "$target_repo/$p" ]] && test_dirs+=("$target_repo/$p"); done
  test_dirs+=("$core_dir/frontend/discourse/tests" "$core_dir/spec/system")
fi
test_re="\b${resolver_name}(-test)?\b"
[[ -n "$class_name" ]] && test_re="${test_re}|\b${class_name}\b"
grep -rlE -- "$test_re" "${test_dirs[@]}" 2>/dev/null | strip_root | awk '!seen[$0]++' | prefix "" || true
selectors="$( { printf '%s\n' "$class_part" | grep -oE '@classNames\([^)]*\)' | grep -oE '"[^"]+"' | tr -d '"' | tr ' ' '\n' | sed 's/^/./';
                printf '%s\n' "$class_part" | grep -oE 'elementId\s*=\s*"[^"]+"' | grep -oE '"[^"]+"' | tr -d '"' | sed 's/^/#/';
                printf '%s\n' "$template_part" | grep -oE '(^|[ (])id="[^"{]+"' | grep -oE '"[^"]+"' | tr -d '"' | sed 's/^/#/';
                printf '%s\n' "$template_part" | grep -oE '@id="[^"{]+"' | grep -oE '"[^"]+"' | tr -d '"' | sed 's/^/#/';
                printf '%s\n' "$template_part" | grep -oE 'class="[^"{]+"' | sed -E 's/class="//; s/"$//' | tr ' ' '\n' | grep -E '^[a-z][a-z0-9_-]+$' | sed 's/^/./'; } | sort -u)"
generic='^\.(btn|btn-primary|btn-default|btn-danger|btn-flat|btn-icon|btn-small|btn-large|btn-text|close-btn|cancel|save|submit|controls|control-group|form-horizontal|hidden|active|disabled|d-icon|selected|loading|title|description|header|footer|content|wrapper|container|row|col|label|input|link|list|item|text|icon|form|error|warning|success|info|inline|block|open|closed|show|hide|clearfix|pull-left|pull-right)$'
selectors="$(printf '%s\n' "$selectors" | grep -vE "$generic" | grep -v '^\.$' | grep -v '^#$' || true)"
if [[ -n "$selectors" ]]; then
  echo "  -- specs and tests referencing selectors ($(echo "$selectors" | tr '\n' ' '))"
  sel_re="$(printf '%s\n' "$selectors" | sed -E 's/[.#]//' | tr '\n' '|' | sed 's/|$//')"
  grep -rlE -- "[.#\"'](${sel_re})([^A-Za-z0-9_-]|\$)" "${test_dirs[@]}" 2>/dev/null | strip_root | awk '!seen[$0]++' | prefix "" | head -40 || true
else
  echo "  -- no ids or non-generic classes found in the template; grep specs by the wrapper classes manually"
fi
# Selector greps miss the test that actually exercises the component when its classes are
# generic (.field, .value). The page each call site belongs to usually has an acceptance
# test named after it, so match test FILENAMES against each call site's path.
site_files="$(printf '%s\n' "$call_sites" | grep -v '^$' | cut -d: -f1 | sort -u)"
if [[ -n "$site_files" ]]; then
  site_name_re="$(while read -r sf; do
      [[ -z "$sf" ]] && continue
      stem="${sf%.*}"
      # a one-word basename (index, user, show) matches half the test suite; only the
      # directory-qualified form is specific enough to be worth printing
      [[ "${stem##*/}" == *-* ]] && printf '%s\n' "${stem##*/}"
      printf '%s\n' "$(basename "$(dirname "$stem")")-${stem##*/}"
    done <<<"$site_files" | sort -u | tr '\n' '|' | sed 's/|$//')"
  if [[ -n "$site_name_re" ]]; then
    site_tests="$(find "${test_dirs[@]}" -type f \( -name '*-test.js' -o -name '*-test.gjs' -o -name '*_spec.rb' \) 2>/dev/null \
      | grep -E "/(${site_name_re})[-_](test|spec)\.[a-z]+$" || true)"
    if [[ -n "$site_tests" ]]; then
      echo "  -- tests named after a call site's page (run these; they cover the component in situ)"
      printf '%s\n' "$site_tests" | strip_root | prefix "" || true
    fi
  fi
fi
