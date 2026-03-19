# Schema Configuration DSL

The schema DSL defines the structure of a database used during migrations. It maps source Discourse
tables to a schema, letting you control which columns to include, rename columns, override types,
add synthetic columns, and define enums.

Config files live in `migrations/config/schema/<database>/` (e.g. `intermediate_db`).

## File layout

```
migrations/config/schema/intermediate_db/
  config.rb          # Output paths and namespaces
  conventions.rb     # Global column conventions (renames, type overrides)
  ignored.rb         # Tables and plugins to exclude
  tables/            # One file per table
    users.rb
    topics.rb
    ...
  enums/             # One file per enum
    upload_type.rb
    ...
```

## CLI commands

| Command                                | Description                                                |
|----------------------------------------|------------------------------------------------------------|
| `schema add TABLE`                     | Create a config file for a new table                       |
| `schema validate`                      | Validate config against the database                       |
| `schema diff`                          | Show differences between config and database               |
| `schema generate`                      | Generate SQL schema, Ruby models, and enum files           |
| `schema list`                          | List configured tables and enums, plus ignored table count |
| `schema ignore TABLE [--reason "..."]` | Add a table to `ignored.rb`                                |
| `schema refresh-plugins`               | Regenerate the plugin manifest                             |

All commands accept `--db NAME` (default: `intermediate_db`).

## Table configuration

Each table has its own file in `tables/`. The basic structure:

```ruby
# frozen_string_literal: true

Migrations::Database::Schema.table :users do
  include_all
end
```

### Column inclusion strategy

Every source-backed table must specify a column inclusion strategy. There are four approaches:

#### `include_all`

Include every column from the source table. Simplest starting point.

```ruby
Migrations::Database::Schema.table :users do
  include_all
end
```

#### `include`

Include only specific columns. Remaining columns must be explicitly passed to `ignore` — the
validator requires every database column to be accounted for, so new columns are never silently
excluded.

```ruby
Migrations::Database::Schema.table :users do
  include :id, :username, :email, :created_at
  ignore :admin, :moderator, reason: "Not needed"
end
```

#### `include!`

Include columns that are globally ignored (via conventions) or auto-ignored (via plugins). Regular
`include` will produce a validation error for such columns; use `include!` to explicitly override.

```ruby
Migrations::Database::Schema.table :users do
  include :id, :username
  include! :updated_at # override global ignore from conventions
end
```

#### `ignore`

Exclude specific columns; all others are included (implies `include_all`). You should provide a
reason.

```ruby
Migrations::Database::Schema.table :topics do
  ignore :bumped_at, :excerpt, :fancy_title, reason: "Calculated columns"
end
```

### Column options

Use `column` to set options on an included source column:

```ruby
Migrations::Database::Schema.table :users do
  include_all

  column :username, required: true
  column :bio, max_length: 3000
  column :name, rename_to: :display_name
  column :trust_level, type: :numeric
end
```

Available options:

- `type:` - Override the column type (`:text`, `:numeric`, `:boolean`, `:datetime`, `:blob`)
- `required:` - Mark the column as NOT NULL (`true` or `false`)
- `max_length:` - Set a maximum length constraint
- `rename_to:` - Rename the column in the schema

Block syntax is also supported:

```ruby
column :id do
  rename_to :original_id
  type :numeric
end
```

### Adding columns

Use `add_column` for columns that don't exist in the source table:

```ruby
Migrations::Database::Schema.table :uploads do
  synthetic!

  add_column :id, :text
  add_column :filename, :text, required: true
  add_column :type, :text, enum: :upload_type
end
```

Options:

- `required:` - Mark as NOT NULL (default: `false`)
- `enum:` - Reference a defined enum for validation

### Primary keys

Override the primary key when it differs from the source:

```ruby
Migrations::Database::Schema.table :user_field_values do
  copy_structure_from :user_custom_fields
  primary_key :user_id, :field_id, :value
end
```

Single-column primary keys detected from the source are used automatically.

### Source table

#### `copy_structure_from`

Use a different database table as the column source. The resolver reads the actual database columns
from the specified table — it does not copy another table's DSL configuration.

```ruby
Migrations::Database::Schema.table :user_field_values do
  copy_structure_from :user_custom_fields
  # columns are read from user_custom_fields in the database
end
```

#### `synthetic!`

The table has no source table. Only `add_column` is allowed.

```ruby
Migrations::Database::Schema.table :uploads do
  synthetic!

  add_column :id, :text
  add_column :filename, :text, required: true
end
```

### Indexes

Use `index` or `unique_index` to define indexes on one or more columns:

```ruby
index :user_id, :topic_id
unique_index :username
unique_index %i[user_id field_id], where: "value IS NOT NULL"
index :status, name: :idx_custom_name
```

Options:

- `name:` - Override the index name (default: auto-generated from table and column names)
- `where:` - Add a partial index condition (SQL expression)

Column names are required (one or more). They must reference columns that are included, added, or
renamed in the table configuration.

### Constraints

Use `check` to define a check constraint. Both arguments are required.

```ruby
check :positive_score, "score >= 0"
```

Arguments:

- First: constraint name (symbol or string)
- Second: SQL condition (string)

### Plugin support

Columns from plugins listed in `ignored.rb` are always auto-ignored automatically. Use
`ignore_plugin_columns!` for non-ignored plugins whose columns you don't want in the intermediate
schema.

Auto-ignore columns from all non-ignored plugins:

```ruby
Migrations::Database::Schema.table :users do
  include_all
  ignore_plugin_columns!
end
```

Auto-ignore columns from specific plugins only:

```ruby
Migrations::Database::Schema.table :users do
  include_all
  ignore_plugin_columns! :polls, :discourse_ai
end
```

### Model mode

Controls how `schema generate` handles the Ruby model file for this table. There are three modes:

**Default** (no `model` declaration) — the model file is fully regenerated on every run. Any manual
edits will be overwritten.

**`model :extended`** — the model file is regenerated, but custom code between the marker comments
is preserved:

```ruby
model :extended
```

The generated file will contain a section like this:

```ruby
    # -- custom code --
# your custom methods and logic here
# -- end custom code --
```

Code between the markers survives regeneration. Code outside the markers is overwritten.

**`model :manual`** — the model file is not generated at all. Use this when you need full control
and will write the model yourself.

```ruby
model :manual
```

## Conventions

Global column conventions apply across all tables. Defined in `conventions.rb`:

```ruby
Migrations::Database::Schema.conventions do
  # Exact column name match
  column :id do
    rename_to :original_id
    type :numeric
  end

  column :created_at do
    required false
  end

  # Regex pattern match
  columns_matching(/.*upload.*_id$/) { type :text }
  columns_matching(/.*_id$/) { type :numeric }

  # Globally ignored columns (excluded from all tables)
  ignore_columns :updated_at
end
```

Convention methods:

- `column :name` - Match a specific column name, then set `rename_to`, `type`, `required`
- `columns_matching /pattern/` - Match columns by regex pattern
- `ignore_columns :col1, :col2` - Globally ignore columns across all tables

Conventions are applied during schema resolution. Per-table `column` options take precedence.

## Enums

Enums define named value sets. Defined in `enums/`. All values in an enum must be the same type —
either all integers or all strings.

Integer enum:

```ruby
Migrations::Database::Schema.enum :visibility do
  value :public, 0
  value :private, 1
  value :restricted, 2
end
```

String enum:

```ruby
Migrations::Database::Schema.enum :color do
  value :red, "red"
  value :green, "green"
  value :blue, "blue"
end
```

From a Ruby constant (must return a Hash or Array):

```ruby
Migrations::Database::Schema.enum :upload_type do
  source { ::UploadCreator::TYPES_TO_CROP }
end
```

## Ignored tables

Tables and plugins to exclude entirely. Defined in `ignored.rb`:

```ruby
Migrations::Database::Schema.ignored do
  # Ignore all tables and columns from a plugin
  plugin :chat, "Not migrated yet"

  # Ignore specific tables (reason is optional)
  table :user_actions, "Not needed"
  table :drafts
  tables :notifications, :bookmarks, reason: "Not needed"
end
```

## Output configuration

Controls where `schema generate` writes the SQL schema file, Ruby models, and enum modules. Defined
in `config.rb`:

```ruby
Migrations::Database::Schema.configure do
  output do
    schema_file "db/intermediate_db_schema/100-base-schema.sql"

    models_directory "lib/database/intermediate_db"
    models_namespace "Migrations::Database::IntermediateDB"

    enums_directory "lib/database/intermediate_db/enums"
    enums_namespace "Migrations::Database::IntermediateDB::Enums"
  end
end
```

## Workflow

1. **Add** a new table: `schema add users`
2. **Edit** the generated file in `tables/users.rb`
3. **Validate** your config: `schema validate`
4. **Check differences**: `schema diff`
5. **Generate** the schema, models, and enums: `schema generate`
