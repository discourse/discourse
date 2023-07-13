# frozen_string_literal: true

class AllowlistAndBlocklistSiteSettings < ActiveRecord::Migration[6.0]
  def up
    SiteSetting::ALLOWLIST_DEPRECATED_SITE_SETTINGS.each_pair { |old_key, new_key| DB.exec <<~SQL }
        INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
        SELECT '#{new_key}', data_type, value, created_at, updated_At
        FROM site_settings
        WHERE name = '#{old_key}'
      SQL
  end

  def down
    SiteSetting::ALLOWLIST_DEPRECATED_SITE_SETTINGS.each_pair { |_old_key, new_key| DB.exec <<~SQL }
        DELETE FROM site_settings
        WHERE name = '#{new_key}'
      SQL
  end
end
