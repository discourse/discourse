# frozen_string_literal: true

class FillEmbeddedMediaPostAllowedGroupsBasedOnDeprecatedSetting < ActiveRecord::Migration[7.0]
  def up
    old_setting_trust_level =
      DB.query_single(
        "SELECT value FROM site_settings WHERE name = 'min_trust_to_post_embedded_media' LIMIT 1",
      ).first

    if old_setting_trust_level.present?
      allowed_groups = "1#{old_setting_trust_level}"

      DB.exec(
        "INSERT INTO site_settings(name, value, data_type, created_at, updated_at)
        VALUES('embedded_media_post_allowed_groups', :setting, '20', NOW(), NOW())
        ON CONFLICT (name) DO NOTHING",
        setting: allowed_groups,
      )
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
