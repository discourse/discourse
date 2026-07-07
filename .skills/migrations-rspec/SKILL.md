---
name: migrations-rspec
description: Use when writing or running RSpec tests for the migrations gems (migrations/core, tooling, converters, importer) — their conventions differ from core Discourse specs (no Rails by default, no fabricators, verified doubles, :rails tag)
---

# RSpec in the migrations gems

The four gems (`migrations/{core,tooling,converters,importer}`) have isolated,
Rails-free spec suites. Do **not** carry core Discourse spec habits over:
no `rails_helper`, no `fab!`/Fabricators, no mocha-style stubbing, no shared
Postgres test database.

## Running

Each gem runs from its own directory with its own Gemfile:

```bash
cd migrations/core && bundle exec rspec              # likewise tooling, converters, importer
```

Specs that need a booted Rails/Discourse environment are tagged `:rails`,
excluded by default, and run against the host app's bundle:

```bash
cd migrations/<gem> && BUNDLE_GEMFILE=../../Gemfile MIGRATIONS_RAILS=1 bundle exec rspec --tag rails
```

`MIGRATIONS_RAILS=1` does double duty: it boots Rails and lifts the `:rails`
exclusion filter. CI (`.github/workflows/migration-tests.yml`) runs both
suites per gem plus `disco check`; core's Tests workflow ignores
`migrations/**` entirely.

If `bundle exec` fails oddly inside a gem, the gitignored per-gem
`Gemfile.lock` may be stale — delete it and `bundle install` rather than
debugging bundler.

## Shared setup

All four `spec_helper.rb`s delegate to `core/spec/spec_setup.rb`
(`MigrationsSpecSetup.call`). What it configures:

- **rspec-mocks only, verified.** The suites are mocha-free by policy (the
  MultiMock adapter registers mocha solely so shared core code doesn't
  break). `verify_partial_doubles = true` is set globally — partial stubs of
  methods that don't exist fail.
- `:rails` exclusion filter (unless `MIGRATIONS_RAILS`), i18n, and autoload
  of `core/spec/support/**` into every gem's suite.

## Tagging `:rails`

Tag the smallest scope that truly needs Rails — a `context`, not the whole
file, when only some examples touch the live DB:

```ruby
context "with a real database connection", :rails do
```

Needing `:rails` means: ActiveRecord introspection, real Postgres, plugin
manifests, `DiscourseDB`. Everything else (SQLite, forking, pure logic)
belongs in the default suite.

## Test data and doubles

- **No fabricators.** Build data inline: plain hashes, Structs, small builder
  methods in the spec.
- **Real SQLite over mocks** for database behavior: `Dir.mktmpdir` + 
  `Migrations::Database.connect(path)` (or `Database::Connection.new(path:)`),
  close in `ensure`/`after`. No `:memory:` databases — tmpdir files.
- **Cross-gem constants** can't be loaded (each gem's suite is isolated), so
  stand them in with a doubled constant:

  ```ruby
  converters = class_double("Migrations::Converters").as_stubbed_const
  allow(converters).to receive(:names).and_return(%w[discourse])
  ```

- `stub_const` is for throwaway test classes/namespaces (fake models, dynamic
  step classes), not cross-gem references.

## Shared support (from `core/spec/support/`)

- `reset_memoization(instance, :@var)` and `fixture_root` (`helpers.rb`)
- Matchers: `have_constant(:X)`, `have_queue_contents(...)`
- Shared examples: `"a database connection"`, `"a database entity"`
- TUI drivers: `support/tui/ansi_screen.rb`, `support/tui/reporter_driver.rb`
- Output assertions: `StringIO` injection or the built-in `output(...).to_stdout`

## Fork-safety specs

New source DB adapters need the fork-safety spec pattern from
`converters/spec/lib/migrations/converters/adapter/postgres_spec.rb`: prove
the parent's connection survives a forked child exiting.

```ruby
expect(adapter.query_value("SELECT 1")).to eq(1)
_, status = Process.waitpid2(Migrations::ForkManager.fork {})
expect(status).to be_success
expect(adapter.query_value("SELECT 1")).to eq(1)
```

Use `Migrations::ForkManager.fork` (not bare `Process.fork`) so the adapter's
after-fork hooks run. Child-side assertions communicate via exit status
(`exit!(0)` / `exit!(1)` + `waitpid2`).

## Structure

- Spec paths mirror lib paths (`<gem>/spec/lib/...`).
- Top form is `RSpec.describe SomeClass do`, with `described_class`,
  `subject`, and `let` as usual.

## Review checklist

1. No mocha syntax (`.stubs`, `.expects`, `.any_instance`) — rspec-mocks only
2. Doubles are verified (`instance_double`, `class_double`); cross-gem
   constants via `class_double(...).as_stubbed_const`
3. No `fab!`/`Fabricate` outside `:rails` specs (and prefer plain data even there)
4. `:rails` tag on the narrowest scope that needs it; spec runs green in the
   default (no-Rails) suite
5. SQLite specs use `Dir.mktmpdir` and close their connections
6. Forking specs use `Migrations::ForkManager.fork`
