# frozen_string_literal: true

Migrations::Database::Schema.ignored do
  table :schema_migrations, "Rails internal table"
  table :ar_internal_metadata, "Rails internal table"
  tables :temp_data, :old_logs, reason: "Legacy tables no longer in use"
end
