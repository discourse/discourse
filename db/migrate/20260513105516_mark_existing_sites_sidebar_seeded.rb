# frozen_string_literal: true

class MarkExistingSitesSidebarSeeded < ActiveRecord::Migration[8.0]
  def up
    return if Migration::Helpers.new_site?

    execute(<<~SQL)
      INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
      VALUES ('sidebar_seeded', 5, 't', NOW(), NOW())
      ON CONFLICT (name) DO UPDATE SET value = 't', updated_at = NOW()
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
