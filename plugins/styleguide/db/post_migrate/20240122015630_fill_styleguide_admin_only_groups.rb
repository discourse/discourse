# frozen_string_literal: true

class FillStyleguideAdminOnlyGroups < ActiveRecord::Migration[7.0]
  def up
    old_setting =
      DB.query_single(
        "SELECT value FROM site_settings WHERE name = 'styleguide_admin_only' LIMIT 1",
      ).first

    if old_setting.present?
      allowed_groups = old_setting == "t" ? "1" : "14" # use admins AUTO_GROUP if true, otherwise default to TL4

      DB.exec(
        "INSERT INTO site_settings(name, value, data_type, created_at, updated_at)
        VALUES('styleguide_allowed_groups', :setting, '20', NOW(), NOW())",
        setting: allowed_groups,
      )
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
