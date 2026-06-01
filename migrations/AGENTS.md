# Migrations Tooling - AI Agent Guide

The `migrations/` directory is split into four path-referenced gems:

- `core/` — `Migrations::*`: CLI framework, UI, SQLite schemas, DB infrastructure,
  IntermediateDB models, and the converter framework (`Migrations::Converter::*`).
- `tooling/` — `Migrations::Tooling::*`: the schema DSL, `disco schema` commands, benchmarks.
- `converters/` — `Migrations::Converters::*`: public converter implementations + source adapters.
- `importer/` — `Migrations::Importer::*`: the row importer and the uploads importer.

All four are wired into the root `Gemfile` via `path:` in the optional `:migrations` group.

## CLI

The single binary is `migrations/bin/disco` (commands register dynamically via
`Migrations::CLI::Registry`):

```bash
migrations/bin/disco --help
migrations/bin/disco convert <name>
migrations/bin/disco import
migrations/bin/disco upload
migrations/bin/disco schema generate
migrations/bin/disco schema validate
migrations/bin/disco schema diff
```

Rails is booted lazily: only commands that declare `requires_rails!` (import, upload, schema)
load the Discourse app.

## Running Tests

Each gem has an isolated, no-Rails suite, run from the gem directory:

```bash
cd migrations/core       && bundle exec rspec
cd migrations/tooling    && bundle exec rspec
cd migrations/converters && bundle exec rspec
cd migrations/importer   && bundle exec rspec
```

Specs that need a booted Rails environment are tagged `:rails`. They are excluded by default and
run from the host app's bundle:

```bash
cd migrations/<gem> && BUNDLE_GEMFILE=../../Gemfile MIGRATIONS_RAILS=1 bundle exec rspec --tag rails
```

## Schema DSL

The schema DSL lives in `migrations/tooling/lib/migrations/tooling/schema/dsl/`. Config sources are
in `migrations/tooling/config/schema/`. Generated artifacts (SQL, models, enums) are written into
`migrations/core/`.

Key files:
- `table_builder.rb` - DSL for defining table configs
- `schema_resolver.rb` - Resolves DSL config + DB introspection into final schema
- `conventions_builder.rb` - Global column conventions (renames, type overrides)
- `generator.rb` - Generates SQL, models, and enums from resolved schema
- `validator.rb` - Validates DSL config
- `resolved_schema_validator.rb` - Validates resolved schema before generation

## Linting

```bash
bin/lint path/to/file
bin/lint --fix path/to/file
```

Uses both rubocop and syntax_tree. Always lint changed files.

## Gems

```bash
bundle config set --local with migrations
bundle install
```
