# frozen_string_literal: true

class ChangeEnableAdminSidebarToGroupPostMigration < ActiveRecord::Migration[7.0]
  def change
    enable_admin_sidebar_navigation_raw =
      DB.query_single(
        "SELECT value FROM site_settings WHERE name = 'enable_admin_sidebar_navigation'",
      ).first

    if enable_admin_sidebar_navigation_raw.present? && enable_admin_sidebar_navigation_raw == "t"
      DB.exec(
        "INSERT INTO site_settings(name, value, data_type, created_at, updated_at)
        VALUES('admin_sidebar_enabled_groups', :setting, '20', NOW(), NOW())",
        setting: "1", # 1 is the Group::AUTO_GROUPS[:admins] group id
      )
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
