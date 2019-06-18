# frozen_string_literal: true

class MigrateNativeAppBannerSiteSetting < ActiveRecord::Migration[5.2]
  def up
    execute "INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
             SELECT 'native_app_install_banner_android', 5, value, now(), now()
             FROM site_settings
             WHERE name = 'native_app_install_banner'"

    execute "UPDATE site_settings
             SET name = 'native_app_install_banner_ios'
             WHERE name = 'native_app_install_banner'"
  end

  def down
    execute "UPDATE site_settings
             SET name = 'native_app_install_banner'
             WHERE name = 'native_app_install_banner_ios'"

    execute "DELETE FROM site_settings WHERE name = 'native_app_install_banner_android'"
  end
end
