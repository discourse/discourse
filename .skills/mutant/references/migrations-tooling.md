# Running mutant in migrations-tooling

Read this alongside the vendored `SKILL.md`. The upstream playbook assumes a
single-gem project with a plain `bundle exec mutant run`; our setup differs in a
few ways, and we use mutant differently (an audit, not a 100% gate).

## How to run

Use the wrapper — it runs mutant inside each gem's own bundle with the right
flags:

```sh
migrations/bin/mutant              # every gem with a .mutant.yml
migrations/bin/mutant tooling      # one gem
migrations/bin/mutant tooling 'Migrations::Tooling::Schema::DSL::TableBuilder'
migrations/bin/mutant tooling --since main   # only subjects changed on the branch
```

Anything after the gem name is passed straight to `mutant run`. The public repo
means `--usage opensource` is required; the wrapper adds it.

Running mutant by hand (e.g. for `mutant session subject`) means setting the
gem's bundle yourself:

```sh
cd migrations/tooling
BUNDLE_GEMFILE=$PWD/Gemfile bundle exec mutant run --usage opensource 'Subject#method'
```

## What is in scope

Mutant runs each gem's **isolated** spec suite, which excludes `:rails`-tagged
examples. So a subject is only mutant-able if its spec is **not** `:rails`
tagged — otherwise its covering tests never run and every mutation "survives"
as noise. That tag is the dividing line; the per-gem `.mutant.yml` lists the
pure subjects.

Good targets: pure logic with isolated specs — `tooling/schema/dsl`,
`tooling/coverage`, the importer name finders / `SuffixFinder`. Skip DB / fork /
IO code (core `database`/`conversion`/`common`, importer steps / uploads /
executor) and the converters (all DB-bound steps, ~no specs). Add a new subject
by listing it under `matcher.subjects` in the gem's `.mutant.yml`.

## Gotchas

- **`module_function` breaks mutant.** It creates two copies of each method;
  mutant mutates the private instance copy while specs call the module copy, so
  every mutation survives and the subject reads ~0% despite a fine spec. Use
  `def self.` / `class << self` instead (and see the no-`module_function` house
  style). `def self.` subjects score fine.
- **`Data.define(...) do ... end` bodies are out of reach.** Methods defined
  inside the block passed to `Data.define` can't be matched as a subject under
  the constant name (e.g. `ConventionsConfig`/`IgnoredConfig` in the schema DSL),
  so their logic — including hot precedence and validation code — is never
  mutated. Don't assume a high gem-wide score means that logic is covered; if it
  matters, move it to a named class or test it directly.
- **`Generator` and friends can leak files** (generated `*.rb`) into the working
  tree when a mutation rewrites an output path. Delete strays after a run; the
  `.mutant/` incremental cache is gitignored.
- **Equivalent-mutant baseline.** Even a fully-tested subject lands a few
  percent short on truly equivalent mutants — e.g. `to_i` ↔ `Integer()` on
  guaranteed-digit input, `transform_values!` ↔ `transform_values` when the
  receiver is not reused, a `break <value>` whose value is discarded. That is
  expected; do not contort tests to chase them.

## How we use it here (differs from upstream)

The upstream playbook drives toward 100% coverage with an ignore-list burn-down.
We run mutant as a **non-gating audit**: find weak specs, add the missing tests,
and **accept** the equivalent-mutant remainder rather than maintaining an
`ignore` list. So:

- Run without `--fail-fast` for the audit (you want the full survivor picture).
  Use `--fail-fast` only when deliberately burning one subject down to 100%.
- Prefer **Option A (add a test)**. Before reaching for the playbook's **Option
  B (simplify / accept the mutation)**, check the house Ruby style — e.g. no
  `module_function` or endless methods, prefer `> 0` / `< 0` over
  `.positive?` / `.negative?`. Don't let a mutant "simplification" push code
  against those.
- When a survivor is genuinely equivalent, note it in the report (as the
  playbook says) but don't add an ignore entry just to reach 100%.
- Commit messages use the `MT:` prefix.
