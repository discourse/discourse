# frozen_string_literal: true

class RemoveDeprecatedAllowlistSettings < ActiveRecord::Migration[6.0]
  def up
    SiteSetting::ALLOWLIST_DEPRECATED_SITE_SETTINGS.each_pair do |old_key, _new_key|
      DB.exec <<~SQL
        DELETE FROM site_settings
        WHERE name = '#{old_key}'
      SQL
    end
  end

  def down
    SiteSetting::ALLOWLIST_DEPRECATED_SITE_SETTINGS.each_pair do |old_key, new_key|
      DB.exec <<~SQL
        INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
        SELECT '#{old_key}', data_type, value, created_at, updated_At
        FROM site_settings
        WHERE name = '#{new_key}'
      SQL
    end
  end
end
