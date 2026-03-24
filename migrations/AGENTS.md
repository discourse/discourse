# Migrations Tooling - AI Agent Guide

## Running Tests

Tests must be run from the project root with `--default-path migrations/spec`:

```bash
bin/rspec --default-path migrations/spec
bin/rspec --default-path migrations/spec migrations/spec/lib/database/schema/dsl/
bin/rspec --default-path migrations/spec migrations/spec/path/to/file_spec.rb
```

## CLI

The CLI binary is at `migrations/bin/cli`:

```bash
migrations/bin/cli help
migrations/bin/cli schema generate
migrations/bin/cli schema validate
migrations/bin/cli schema diff
```

## Schema DSL

The schema DSL lives in `migrations/lib/database/schema/dsl/`. Config files are in `migrations/config/schema/`.

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
