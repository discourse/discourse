# frozen_string_literal: true

class KeepThemeForExistingSites < ActiveRecord::Migration[8.0]
  def up
    # explicitly set the old default for existing sites that haven't changed it
    execute <<~SQL if Migration::Helpers.existing_site?
      INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
      VALUES ('default_theme_id', 3, -1, NOW(), NOW())
      ON CONFLICT (name) DO NOTHING
      SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
