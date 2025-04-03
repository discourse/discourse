# frozen_string_literal: true

class XSummaryLargeImageBasedOnDeprecatedSetting < ActiveRecord::Migration[7.2]
  def up
    old_setting =
      DB.query_single(
        "SELECT value FROM site_settings WHERE name = 'twitter_summary_large_image' LIMIT 1",
      ).first

    if old_setting.present?
      DB.exec(
        "INSERT INTO site_settings(name, value, data_type, created_at, updated_at)
        VALUES('x_summary_large_image', :setting, '18', NOW(), NOW())",
        setting: old_setting,
      )
    end
  end

  def down
    old_setting =
      DB.query_single(
        "SELECT value FROM site_settings WHERE name = 'x_summary_large_image' LIMIT 1",
      ).first

    if old_setting.present?
      DB.exec(
        "INSERT INTO site_settings(name, value, data_type, created_at, updated_at)
        VALUES('twitter_summary_large_image', :setting, '18', NOW(), NOW())
        ON CONFLICT DO UPDATE",
        setting: old_setting,
      )
    end
  end
end
