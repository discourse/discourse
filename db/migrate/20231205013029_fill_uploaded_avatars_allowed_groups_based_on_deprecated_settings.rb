# frozen_string_literal: true

class FillUploadedAvatarsAllowedGroupsBasedOnDeprecatedSettings < ActiveRecord::Migration[7.0]
  def up
    old_setting_trust_level =
      DB.query_single(
        "SELECT value FROM site_settings WHERE name = 'allow_uploaded_avatars' LIMIT 1",
      ).first

    if old_setting_trust_level.present?
      group_id =
        case old_setting_trust_level
        when "disabled"
          ""
        when "admin"
          "1"
        when "staff"
          "3"
        else
          "1#{old_setting_trust_level}"
        end

      DB.exec(
        "INSERT INTO site_settings(name, value, data_type, created_at, updated_at)
        VALUES('uploaded_avatars_allowed_groups', :setting, '20', NOW(), NOW())",
        setting: group_id,
      )
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
