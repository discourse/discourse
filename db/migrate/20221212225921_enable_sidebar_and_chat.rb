# frozen_string_literal: true

class EnableSidebarAndChat < ActiveRecord::Migration[7.0]
  def up
    # keep sidebar legacy and chat disabled for existing sites
    if Migration::Helpers.existing_site?
      execute <<~SQL
        INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
        VALUES('chat_enabled', 5, 'f', NOW(), NOW())
        ON CONFLICT (name) DO NOTHING
      SQL
      execute <<~SQL
        INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
        VALUES('navigation_menu', 7, 'legacy', NOW(), NOW())
        ON CONFLICT (name) DO NOTHING
      SQL
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
