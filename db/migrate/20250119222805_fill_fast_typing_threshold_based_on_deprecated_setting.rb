# frozen_string_literal: true

class FillFastTypingThresholdBasedOnDeprecatedSetting < ActiveRecord::Migration[7.2]
  def up
    old_setting_value =
      DB.query_single(
        "SELECT value FROM site_settings WHERE name = 'min_first_post_typing_time' LIMIT 1",
      ).first

    if old_setting_value.present?
      fast_typing_threshold_setting =
        case
        when old_setting_value.to_i == NewPostManager::FAST_TYPING_THRESHOLD_MAP[:disabled]
          "off"
        when old_setting_value.to_i < NewPostManager::FAST_TYPING_THRESHOLD_MAP[:standard]
          "low"
        when old_setting_value.to_i < NewPostManager::FAST_TYPING_THRESHOLD_MAP[:high]
          "standard"
        else
          "high"
        end
      puts fast_typing_threshold_setting

      DB.exec(
        "INSERT INTO site_settings(name, value, data_type, created_at, updated_at)
        VALUES('fast_typing_threshold', :setting, '7', NOW(), NOW())
        ON CONFLICT DO NOTHING",
        setting: fast_typing_threshold_setting,
      )
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
