# Schema Configuration DSL

The schema DSL defines the structure of the intermediate database used during migrations. It maps source Discourse tables to an intermediate schema, letting you control which columns to include, rename columns, override types, add synthetic columns, and define enums.

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

| Command | Description |
|---------|-------------|
| `schema add TABLE` | Create a config file for a new table |
| `schema validate` | Validate config against the database |
| `schema diff` | Show differences between config and database |
| `schema resolve` | Show the resolved schema (for debugging) |
| `schema generate` | Generate SQL schema, Ruby models, and enum files |
| `schema list` | List all configured and ignored tables |
| `schema show TABLE` | Show configuration details for a table |
| `schema ignore TABLE [--reason "..."]` | Add a table to `ignored.rb` |
| `schema detect-plugins` | Regenerate the plugin manifest |

All commands accept `--database NAME` (default: `intermediate_db`).

## Table configuration

Each table has its own file in `tables/`. The basic structure:

```ruby
# frozen_string_literal: true

Migrations::Database::Schema.table :users do
  include_all
end
```

### Column inclusion strategy

You must tell the DSL which source columns to include. There are three approaches:

#### `include_all`

Include every column from the source table. Simplest starting point.

```ruby
Migrations::Database::Schema.table :users do
  include_all
end
```

#### `include`

Include only specific columns. Columns not listed are excluded.

```ruby
Migrations::Database::Schema.table :users do
  include :id, :username, :email, :created_at
end
```

#### `include!`

Include columns that are globally ignored (via conventions) or auto-ignored (via plugin). Regular `include` will produce a validation error for such columns; use `include!` to explicitly override.

```ruby
Migrations::Database::Schema.table :users do
  include :id, :username
  include! :updated_at  # override global ignore from conventions
end
```

#### `ignore`

Exclude specific columns; all others are included (implies `include_all`). You should provide a reason.

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
- `rename_to:` - Rename the column in the intermediate schema

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

Use a different source table's columns:

```ruby
Migrations::Database::Schema.table :user_field_values do
  copy_structure_from :user_custom_fields
  # columns come from user_custom_fields, not user_field_values
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

### Indexes and constraints

```ruby
index :user_id, :topic_id, name: :idx_posts_user_topic
unique_index :username, name: :idx_unique_users_username
unique_index %i[user_id field_id], name: :my_index, where: "condition"

check :positive_score, "score >= 0"
```

### Plugin support

```ruby
Migrations::Database::Schema.table :users do
  include_all
  ignore_plugin_columns!                       # auto-ignore columns from ALL non-ignored plugins
  # ignore_plugin_columns! :polls, :discourse_ai  # auto-ignore only from these specific plugins
end

Migrations::Database::Schema.table :chat_messages do
  plugin :chat              # mark this table as belonging to a plugin
  include_all
end
```

Note: Columns from plugins listed in `ignored.rb` are always auto-ignored automatically. `ignore_plugin_columns!` is for non-ignored plugins whose columns you don't want in the intermediate schema.

### Model mode

Controls how the generated Ruby model is structured:

```ruby
model :manual    # don't generate a model class (you'll write it yourself)
model :extended  # generate a model with extensions
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

Enums define named value sets. Defined in `enums/`:

```ruby
Migrations::Database::Schema.enum :upload_type do
  value "avatar", 0
  value "profile_background", 1
  string_value "custom", "custom"
end
```

Or from a Ruby constant:

```ruby
Migrations::Database::Schema.enum :upload_type do
  source "::UploadCreator::TYPES_TO_CROP"
end
```

## Ignored tables

Tables and plugins to exclude entirely. Defined in `ignored.rb`:

```ruby
Migrations::Database::Schema.ignored do
  # Ignore all tables and columns from a plugin
  plugin :chat, "Not migrated yet"

  # Ignore specific tables
  table :user_actions, "Not needed"
  tables :drafts, :notifications, reason: "Not needed"
end
```

## Output configuration

Defined in `config.rb`:

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
