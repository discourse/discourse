class MigrateUrlSiteSettings < ActiveRecord::Migration[5.2]
  def up
    [
      ['logo_url', 'logo'],
      ['logo_small_url', 'logo_small'],
      ['digest_logo_url', 'digest_logo'],
      ['mobile_logo_url', 'mobile_logo'],
      ['large_icon_url', 'large_icon'],
      ['favicon_url', 'favicon'],
      ['apple_touch_icon_url', 'apple_touch_icon'],
      ['default_opengraph_image_url', 'opengraph_image'],
      ['twitter_summary_large_image_url', 'twitter_summary_large_image']
    ].each do |old_setting, new_setting|
      old_url = DB.query_single(
        "SELECT value FROM site_settings WHERE name = '#{old_setting}'"
      ).first

      next if old_url.blank?

      count = 0
      file = nil
      sleep_interval = 5

      loop do
        file = FileHelper.download(
          UrlHelper.absolute(old_url),
          max_file_size: 20.megabytes,
          tmp_file_name: 'tmp_site_setting_logo',
          skip_rate_limit: true,
          follow_redirect: true
        )
        count += 1
        break if file || (file.blank? && count >= 3)
        sleep(count * sleep_interval)
      end

      next if file.blank?

      upload = UploadCreator.new(
        file,
        "#{new_setting}",
        origin: UrlHelper.absolute(old_url),
        for_site_setting: true
      ).create_for(Discourse.system_user.id)

      execute <<~SQL
      INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
      VALUES ('#{new_setting}', 18, #{upload.id}, now(), now())
      SQL
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
