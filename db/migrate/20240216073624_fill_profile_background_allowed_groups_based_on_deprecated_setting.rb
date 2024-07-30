# frozen_string_literal: true

class FillProfileBackgroundAllowedGroupsBasedOnDeprecatedSetting < ActiveRecord::Migration[7.0]
  def up
    old_setting_trust_level =
      DB.query_single(
        "SELECT value FROM site_settings WHERE name = 'min_trust_level_to_allow_profile_background' LIMIT 1",
      ).first

    if old_setting_trust_level.present?
      allowed_groups = "3|1#{old_setting_trust_level}" # allow staff and the TL auto group

      DB.exec(
        "INSERT INTO site_settings(name, value, data_type, created_at, updated_at)
        VALUES('profile_background_allowed_groups', :setting, '20', NOW(), NOW())",
        setting: allowed_groups,
      )
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
