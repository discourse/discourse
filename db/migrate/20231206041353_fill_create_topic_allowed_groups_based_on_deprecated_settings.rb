# frozen_string_literal: true

class FillCreateTopicAllowedGroupsBasedOnDeprecatedSettings < ActiveRecord::Migration[7.0]
  def up
    old_setting_trust_level =
      DB.query_single(
        "SELECT value FROM site_settings WHERE name = 'min_trust_to_create_topic' LIMIT 1",
      ).first

    if old_setting_trust_level.present?
      create_topic_allowed_groups = "1#{old_setting_trust_level}"

      DB.exec(
        "INSERT INTO site_settings(name, value, data_type, created_at, updated_at)
        VALUES('create_topic_allowed_groups', :setting, '20', NOW(), NOW())",
        setting: create_topic_allowed_groups,
      )
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
