# frozen_string_literal: true

class SplitHideProfileAndPresence < ActiveRecord::Migration[7.1]
  def up
    # Split default_hide_profile_and_presence if setting exists
    result =
      execute(
        "SELECT value, data_type FROM site_settings WHERE name = 'default_hide_profile_and_presence' LIMIT 1",
      ).first

    if result
      value = result["value"]
      data_type = result["data_type"]

      execute "DELETE FROM site_settings WHERE name = 'default_hide_profile_and_presence'"
      execute <<-SQL
        INSERT INTO site_settings (name, value, data_type, created_at, updated_at)
        VALUES
          ('default_hide_profile', '#{value}', '#{data_type}', NOW(), NOW()),
          ('default_hide_presence', '#{value}', '#{data_type}', NOW(), NOW());
      SQL
    end

    # Add new columns to user_options
    execute "ALTER TABLE user_options ADD COLUMN hide_profile BOOLEAN DEFAULT FALSE NOT NULL"
    execute "ALTER TABLE user_options ADD COLUMN hide_presence BOOLEAN DEFAULT FALSE NOT NULL"
    execute <<-SQL
      UPDATE user_options
      SET hide_profile = hide_profile_and_presence,
          hide_presence = hide_profile_and_presence
      WHERE hide_profile_and_presence;
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
