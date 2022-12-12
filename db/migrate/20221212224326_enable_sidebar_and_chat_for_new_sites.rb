# frozen_string_literal: true

class EnableSidebarAndChatForNewSites < ActiveRecord::Migration[7.0]
  def up
    result = execute <<~SQL
      SELECT created_at
      FROM schema_migration_details
      ORDER BY created_at
      LIMIT 1
    SQL

    if result.first['created_at'].to_datetime < 1.hour.ago
      execute <<~SQL
        INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
        VALUES('chat_enabled', 5, 't', NOW(), NOW())
        ON CONFLICT (name) DO NOTHING
      SQL
      execute <<~SQL
        INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
        VALUES('navigation_menu', 7, 'sidebar', NOW(), NOW())
        ON CONFLICT (name) DO NOTHING
      SQL
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
