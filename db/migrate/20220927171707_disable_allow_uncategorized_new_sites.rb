# frozen_string_literal: true

class DisableAllowUncategorizedNewSites < ActiveRecord::Migration[7.0]
  def up
    # keep allow uncategorized for existing sites
    execute <<~SQL if Migration::Helpers.existing_site?
        INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
        VALUES('allow_uncategorized_topics', 5, 't', NOW(), NOW())
        ON CONFLICT (name) DO NOTHING
      SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
