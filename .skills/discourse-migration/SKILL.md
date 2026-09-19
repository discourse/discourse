---
name: discourse-migration
description: MUST load before writing or reviewing any database migration (db/migrate, db/post_migrate, plugin migrations)
---

# Discourse Migration Skill

Discourse runs zero-downtime deployments. Migrations are split across two directories:

- **`db/migrate/`** — runs pre-deploy. SafeMigrate (`lib/migration/safe_migrate.rb`) **blocks** dropping/renaming tables or columns, and creating concurrent indexes without first dropping them. Raises `Discourse::InvalidMigration` on violation.
- **`db/post_migrate/`** — runs post-deploy (skipped when `SKIP_POST_DEPLOYMENT_MIGRATIONS=1`). No safety restrictions — destructive ops go here.

Plugins mirror this: `plugins/<name>/db/migrate/` and `plugins/<name>/db/post_migrate/`.

SafeMigrate is a dev/test guard only (disabled in production).

## Generating migrations

Always use generators — never hand-write timestamps. Manual timestamps like `120000`/`120001` cause collisions.

```bash
bin/rails g migration CreateWidgets                                          # db/migrate/
bin/rails g post_migration DropOldColumns                                    # db/post_migrate/
bin/rails g plugin_migration CreatePluginTable --plugin-name=my-plugin       # plugins/<name>/db/migrate/
bin/rails g plugin_post_migration DropOldPluginCols --plugin-name=my-plugin  # plugins/<name>/db/post_migrate/
bin/rails g site_setting_rename_migration old_name new_name                  # site setting rename
```

Use `change` for reversible ops, `up`/`down` for irreversible. Use `raise ActiveRecord::IrreversibleMigration` in `down`. Use `up_only { ... }` for data ops inside an otherwise reversible `change`.

## Avoiding application code in migrations

Never call application code (models, `SiteSetting`, etc.) in migrations. These references break when code changes months or years later — settings get removed, methods get renamed, or semantics shift silently.

```ruby
# BAD — relies on application code that may not exist when migration runs later
if SiteSetting.some_setting
  add_column ...
end

# GOOD — query the database directly
result = DB.query_single("SELECT value FROM site_settings WHERE name = 'some_setting'")
if result.first == "t"
  add_column ...
end
```

`execute` is the default for all migration SQL. Only use `DB.exec`/`DB.query` when you need parameterized queries (`:param` syntax) or return values.

## Fresh installs must not gain application rows

Fresh installs provision the database from `db/structure.sql`, which captures schema only — rows are not serialized. Any data a migration inserts on a fresh DB silently disappears on new installs. CI (`db:check_structure_dump`) asserts no application tables have rows after a clean `db:migrate`.

Seed data belongs in `db/fixtures/` (or `plugins/<name>/db/fixtures/`). When a migration on existing sites needs to write rows (e.g. preserve old default behavior), gate the insert on `Migration::Helpers.existing_site?` so fresh installs skip it; pair it with a fixture that handles the new default.

## Safely removing columns

Multi-step process across deployments. Helpers: `lib/migration/column_dropper.rb`, `lib/migration/base_dropper.rb`.

**Step 1 — Mark readonly (regular migration):**

```ruby
class MarkOldColumnReadonly < ActiveRecord::Migration[8.0]
  def up
    change_column_default :my_table, :old_column, nil  # MUST drop default first
    Migration::ColumnDropper.mark_readonly(:my_table, :old_column)
  end

  def down
    Migration::ColumnDropper.drop_readonly(:my_table, :old_column)
  end
end
```

Creates a PG trigger rejecting non-null writes. Old code can still read.

**Step 2 — Ignore in model (code change, same PR):**

```ruby
self.ignored_columns += %i[old_column]
# TODO(MM-YYYY): Remove this line (calculate 6 months from today)
```

Use `+=` to append. Without this, dropping the column causes `StatementInvalid`.

**Step 3 — Drop column (post-deploy migration):**

```ruby
class DropOldColumn < ActiveRecord::Migration[8.0]
  DROPPED_COLUMNS = { my_table: %i[old_column] }

  def up
    DROPPED_COLUMNS.each { |table, columns| Migration::ColumnDropper.execute_drop(table, columns) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
```

**Step 4** — Remove `ignored_columns` entry after post-deploy migration is promoted.

For deprecation warnings before removal: `include HasDeprecatedColumns` then `deprecate_column :col, drop_from: "3.5"` (see `app/models/concerns/has_deprecated_columns.rb`).

## Safely renaming columns

Renaming is a multi-step process similar to column removal:

1. **Pre-deploy migration:** Mark the old column readonly with `Migration::ColumnDropper.mark_readonly`, add the new column, create a trigger to mirror writes from old to new on inserts/updates, and backfill existing data from old column to new.
2. **Code change (same PR):** Update all application code to read/write the new column. Add `self.ignored_columns += %i[old_column]` to the model.
3. **Post-deploy migration:** Drop the old column using `Migration::ColumnDropper.execute_drop`. In most cases, delay this until the rename has been confirmed safe with no data loss.

## Safely removing tables

Same pattern via `lib/migration/table_dropper.rb`:

1. Regular migration: `Migration::TableDropper.read_only_table(:old_table)`
2. Post-deploy migration: `Migration::TableDropper.execute_drop(:old_table)`

If table is already fully unused, just `drop_table` directly in a post-deploy migration.

## Removing site settings

The most common migration type. Use `execute` with `DELETE` or `UPDATE`:

```ruby
# Removal
execute "DELETE FROM site_settings WHERE name = 'old_setting_name'"

# Rename
execute "UPDATE site_settings SET name = 'new_name' WHERE name = 'old_name'"
```

Always `up`/`down` with `raise ActiveRecord::IrreversibleMigration`.

## Indexing

### Concurrent indexes

Large or busy existing tables require concurrent indexing. Always pair with `disable_ddl_transaction!`. SafeMigrate requires dropping the old index first:

```ruby
class AddIndexToWidgets < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    remove_index :widgets, :user_id, algorithm: :concurrently, if_exists: true
    add_index :widgets, :user_id, algorithm: :concurrently
  end
end
```

New tables and small/low-traffic existing tables can use regular (non-concurrent) indexes.

### Partial indexes

Use `where:` to reduce index size — common for soft-deletes, nullable uniques, type scoping:

```ruby
add_index :topic_timers, [:topic_id], where: "deleted_at IS NULL"
add_index :email_logs, [:bounce_key], unique: true, where: "bounce_key IS NOT NULL"
add_index :users, [:id], name: "idx_users_admin", where: "admin"
```

### Composite indexes

Order: equality conditions first, then range/sort. Add both directions for join tables:

```ruby
add_index :topic_allowed_users, %i[topic_id user_id], unique: true
add_index :topic_allowed_users, %i[user_id topic_id], unique: true
```

### GiST indexes

For trigram search: `using: "gist", opclass: :gist_trgm_ops`.

### Naming

Default Rails naming works unless the name exceeds 63 chars (PG limit) — then use a custom `name:`.

## Transaction-disabled migrations

Do not perform schema changes (`add_column`, `remove_column`, `rename_column`, `change_column`, `change_column_null`, `create_table`, `drop_table`, etc.) in a migration that calls `disable_ddl_transaction!`.

Without the wrapping transaction, each statement autocommits. If the migration runs several statements and one fails partway through, the completed statements are committed and won't roll back, leaving the schema half-migrated and hard to recover.

`disable_ddl_transaction!` is only for operations that can't run inside a transaction block: concurrent index creation (see Indexing) and batched data backfills (see Data backfills). Keep such a migration limited to the single operation that requires it, and move any other schema changes to a separate migration that keeps its DDL transaction so they stay atomic.

## Foreign keys

**Discourse mostly does NOT use foreign keys.** Referential integrity is enforced by application logic and `EnsureDbConsistency` (`app/jobs/scheduled/ensure_db_consistency.rb`), which runs every 12 hours calling `ensure_consistency!` on 18 core models.

**Why:** avoids lock contention, simplifies soft-deletes and bulk ops, prevents unexpected cascading deletes.

**Exceptions:** FKs are used selectively for critical relationships (uploads, security keys). Cascade deletes are rare (2 instances in codebase). Default: don't add FKs.

## Data backfills

Lightweight updates (e.g., nulling `baked_version` for rebake) on large tables are fine unbatched if the WHERE clause limits scope. For heavy data writes on large tables, batch with `disable_ddl_transaction!`:

```ruby
class BackfillData < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!
  BATCH_SIZE = 30_000

  def up
    loop do
      count = DB.exec(<<~SQL, batch_size: BATCH_SIZE)
        WITH cte AS (
          SELECT id, other_col FROM my_table WHERE new_col IS NULL LIMIT :batch_size
        )
        UPDATE my_table SET new_col = cte.other_col FROM cte WHERE my_table.id = cte.id
      SQL
      break if count == 0
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
```

Use `ON CONFLICT` for idempotent inserts. Use parameterized queries (`:param` syntax via `DB.exec`) — not string interpolation.

## Conditional logic

Use `Migration::Helpers` (`lib/migration/helpers.rb`) for install-vs-upgrade behavior:

```ruby
if Migration::Helpers.existing_site?  # site created > 1 hour ago
  # e.g., insert a site setting to disable new feature for existing sites
end
```

Use `column_exists?`, `table_exists?`, `index_exists?` for idempotency guards.

## NOT NULL constraints and NULLable columns

Avoid NULLable columns whenever possible — every NULL field is a potential `nil` error. Prefer adding a default (e.g., `false` for booleans, `""` for strings, `0` for counts). Limit NULLs to truly optional fields (optional description, optional URL).

When adding a NOT NULL constraint to an existing column, always clean data first: `DELETE` invalid rows or `UPDATE` nulls to a default, then `change_column_null`.

## Bigint conversions

For large tables (e.g. `notifications.id`), use four migrations:
1. Add shadow bigint column + insert-mirroring trigger
2. Batch-copy existing rows (`disable_ddl_transaction!`, ~10k batches)
3. Swap columns (rename old/new, fix PK/sequences, mark old readonly)
4. Post-deploy: `execute_drop` the old column

## Testing migrations

When a migration includes data changes with potential for data loss or inaccuracy, write an RSpec test. Migration files aren't auto-loaded, so require them explicitly:

```ruby
# frozen_string_literal: true

require Rails.root.join("db/migrate/20240101000000_backfill_widget_status.rb")

RSpec.describe BackfillWidgetStatus do
  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
  end

  after { ActiveRecord::Migration.verbose = @original_verbose }

  it "backfills status from legacy column" do
    # Set up test data with fabricators or DB.exec

    described_class.new.up

    # Assert expected state
  end
end
```

The same pattern works for plugin migrations — just adjust the `require` path (e.g., `plugins/chat/db/migrate/...`).

## Regenerating structure.sql and annotations

After any schema-altering migration (columns, tables, indexes), regenerate both `db/structure.sql` and model annotations. CI fails if either is stale.

```bash
bin/rake db:dump_structure   # rewrites db/structure.sql from a clean migrated DB
bin/rake annotate:clean      # rewrites all model annotations (core + bundled plugins)
```

Both tasks spin up a disposable database and load all bundled plugins, so output is invariant to the local `plugins/` directory. Commit the regenerated files alongside the migration.

## Review checklist

1. Destructive ops in `db/post_migrate/`, everything else in `db/migrate/`
2. Timestamp from generator, not hand-written
3. `# frozen_string_literal: true` and `ActiveRecord::Migration[8.0]`
4. Concurrent indexes on large/busy tables: `disable_ddl_transaction!` + `remove_index ... if_exists: true` before `add_index`
5. Column drops: full lifecycle (mark_readonly -> ignored_columns -> execute_drop)
6. Default dropped before `mark_readonly`
7. Heavy data writes on large tables batched with `disable_ddl_transaction!`
8. Idempotent: `IF EXISTS`, `ON CONFLICT`, `column_exists?`, etc.
9. Rollback: `down` method or `raise ActiveRecord::IrreversibleMigration`
10. No foreign keys unless strong justification
11. No application code (models, `SiteSetting`) — query DB directly
12. `execute` for SQL; `DB.exec`/`DB.query` only when param binding or return values needed
13. No rows inserted on fresh installs — seed data lives in `db/fixtures/`; inserts that exist only to preserve behavior on upgrades are gated on `Migration::Helpers.existing_site?`
14. After schema-altering migrations, `bin/rake db:dump_structure` and `bin/rake annotate:clean` were run and the regenerated files committed
15. Transaction-disabled migrations (`disable_ddl_transaction!`) contain only the operation that requires it (concurrent index or batched backfill), no other schema changes
