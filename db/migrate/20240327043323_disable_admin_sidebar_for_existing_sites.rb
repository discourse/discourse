# frozen_string_literal: true

class DisableAdminSidebarForExistingSites < ActiveRecord::Migration[7.0]
  def up
    # keep old admin menu for existing sites
    execute <<~SQL if Migration::Helpers.existing_site?
      INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
      VALUES('admin_sidebar_enabled_groups', 20, '-1', NOW(), NOW())
      ON CONFLICT (name) DO NOTHING
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
