# frozen_string_literal: true

class SetTaggingEnabled < ActiveRecord::Migration[6.1]
  def up
    # keep tagging disabled for existing sites
    execute <<~SQL if Migration::Helpers.existing_site?
        INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
        VALUES('tagging_enabled', 5, 'f', NOW(), NOW())
        ON CONFLICT (name) DO NOTHING
      SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
