---
name: migrations-schema-dsl
description: Use when changing the IntermediateDB schema — editing config under migrations/tooling/config/schema, running disco schema commands, or touching generated files in migrations/core (SQL schema, IntermediateDB models, enums)
---

# IntermediateDB schema DSL

The IntermediateDB schema is **generated**: DSL config in
`migrations/tooling/config/schema/intermediate_db/` is resolved against the
live Discourse database and written out as SQL, models, and enums in
`migrations/core/`. The full DSL reference is
`migrations/docs/schema-configuration.md` — read it before editing config.
This skill covers the workflow, the moving parts, and the traps.

## Never hand-edit generated files

Generated files carry this header and are rewritten (or deleted, when stale)
on every `disco schema generate`:

```
# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the configuration files in "migrations/tooling/config/schema/" and then run
# `migrations/bin/disco schema generate` to regenerate this file.
```

Generated artifacts (paths set in `config.rb`):

- `migrations/core/db/intermediate_db_schema/100-base-schema.sql` — one
  `CREATE TABLE` per table
- `migrations/core/lib/migrations/database/intermediate_db/*.rb` — one model
  per table (except `model :manual` tables, which get none; `model :extended`
  files keep hand-written code between custom-code markers)
- `migrations/core/lib/migrations/database/intermediate_db/enums/*.rb`

CI (`disco check`, in `migration-tests.yml`) regenerates into a temp dir and
byte-compares against the committed files — stale generated output fails the
build. Always commit config change and regenerated files together.

## What the config resolves against

The schema DSL is validated and resolved against the **booted Discourse Rails
app's Postgres database** (ActiveRecord introspection in `validator.rb` and
`schema_resolver.rb`) — not against the SQLite intermediate DB. That's why
every `disco schema` subcommand boots Rails, and why `disco check schema`
first refuses to run with pending migrations: run `bin/rake db:migrate`
before schema work, or validation reports drift that isn't yours.

## Commands

```bash
migrations/bin/disco schema generate            # regenerate SQL + models + enums
migrations/bin/disco schema diff                # config vs database drift, with suggestions
migrations/bin/disco schema add <table>         # scaffold tables/<table>.rb
migrations/bin/disco schema list
migrations/bin/disco schema ignore <table> --reason "..."   # edits ignored.rb
migrations/bin/disco schema unignore <table>
migrations/bin/disco schema refresh-plugins    # regenerate plugin_manifest.yml

migrations/bin/disco check                     # everything CI runs
migrations/bin/disco check schema              # pending migrations → config validity → drift → artifacts current
```

All take `--db <name>` (default `intermediate_db`).

## Config layout

```
tooling/config/schema/intermediate_db/
├── config.rb        # output paths + namespaces
├── conventions.rb   # global column rules (renames, type overrides, global ignores)
├── ignored.rb       # tables excluded from the schema (with reasons)
├── tables/*.rb      # one file per table
└── enums/*.rb
```

A typical table config (`tables/user_emails.rb`):

```ruby
# frozen_string_literal: true

Migrations::Tooling::Schema.table :user_emails do
  primary_key :user_id, :email
  include :email, :primary, :user_id, :created_at
  ignore :id, :normalized_email
end
```

Conventions apply to **all** tables during resolution — the live file renames
`id` → `original_id`, forces `*_id` columns to `:numeric` (upload references
to `:text`), and globally ignores `updated_at`. A column listed in a global
ignore or plugin auto-ignore needs `include!` (not `include`) to override.

## Typical workflows

**New core/plugin table appears in the database** (validation starts failing):
either track it — `disco schema add <table>`, edit the scaffold — or exclude
it: `disco schema ignore <table> --reason "..."`. Then `generate` + `check schema`.

**Change columns of a tracked table:** edit `tables/<table>.rb` (`include` /
`ignore` / `column ... type:` / `add_column` for synthetic columns), then
`generate` + `check schema`.

**Global convention change:** edit `conventions.rb`; expect `generate` to
rewrite many files — review the diff before committing.

Validation errors are collected strings, not exceptions — e.g.
`"Table 'x': included columns do not exist in database: a, b"` or
`"... is globally ignored — use `include!` to override"`. Stale-ignore errors
mean the database moved under the config; `diff` shows the fix.

## Review checklist

1. Only files under `tooling/config/schema/` were hand-edited; everything
   under `core/db/intermediate_db_schema/` and
   `core/lib/migrations/database/intermediate_db/` came from `generate`
2. `disco check schema` passes (implies migrations were up to date and
   artifacts match the config)
3. Config and regenerated artifacts are in the same commit
4. New tables that shouldn't be migrated are in `ignored.rb` with a reason,
   not silently left failing validation
5. `model :extended` custom code sits between the custom-code markers, or it
   is lost on the next `generate`
