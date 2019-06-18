# frozen_string_literal: true

class MigrateBlankOverrideForUploadSiteSettings < ActiveRecord::Migration[5.2]
  def up
    {
      'logo_url' => 'logo',
      'logo_small_url' => 'logo_small',
      'digest_logo_url' => 'digest_logo',
      'mobile_logo_url' => 'mobile_logo',
      'large_icon_url' => 'large_icon',
      'favicon_url' => 'favicon',
      'apple_touch_icon_url' => 'apple_touch_icon',
      'default_opengraph_image_url' => 'opengraph_image',
      'twitter_summary_large_image_url' => 'twitter_summary_large_image',
      'push_notifications_icon_url' => 'push_notifications_icon'
    }.each do |old_name, new_name|
      if DB.query_single("SELECT 1 FROM site_settings WHERE name = '#{old_name}' AND value = ''").present? &&
         DB.query_single("SELECT 1 FROM site_settings WHERE name = '#{new_name}'").empty?

        ActiveRecord::Base.connection.execute <<~SQL
        INSERT INTO site_settings (
          name,
          data_type,
          value,
          created_at,
          updated_at
        ) VALUES (
          '#{new_name}',
          18,
          '',
          CURRENT_TIMESTAMP,
          CURRENT_TIMESTAMP
        )
        SQL
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
