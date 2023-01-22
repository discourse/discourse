# frozen_string_literal: true

class DisableAllowUncategorizedNewSites < ActiveRecord::Migration[7.0]
  def up
    result = execute <<~SQL
      SELECT created_at
      FROM schema_migration_details
      ORDER BY created_at
      LIMIT 1
    SQL

    # keep allow uncategorized for existing sites
    execute <<~SQL if result.first["created_at"].to_datetime < 1.hour.ago
        INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
        VALUES('allow_uncategorized_topics', 5, 't', NOW(), NOW())
        ON CONFLICT (name) DO NOTHING
      SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
