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
      ['twitter_summary_large_image_url', 'twitter_summary_large_image'],
      ['push_notifications_icon_url', 'push_notifications_icon'],
    ].each do |old_setting, new_setting|
      old_url = DB.query_single(
        "SELECT value FROM site_settings WHERE name = '#{old_setting}'"
      ).first

      next if old_url.blank?

      count = 0
      file = nil
      sleep_interval = 5

      loop do
        url = UrlHelper.absolute(old_url)

        begin
          file = FileHelper.download(
            url,
            max_file_size: 20.megabytes,
            tmp_file_name: 'tmp_site_setting_logo',
            skip_rate_limit: true,
            follow_redirect: true
          )
        rescue OpenURI::HTTPError => e
          logger.info(
            "HTTP error encountered when trying to download file " +
            "for #{new_setting}.\n#{e.message}"
          )
        end

        count += 1
        break if file || (file.blank? && count >= 3)

        logger.info(
          "Failed to download upload from #{url} for #{new_setting}. Retrying..."
        )

        sleep(count * sleep_interval)
      end

      next if file.blank?

      upload = UploadCreator.new(
        file,
        "#{new_setting}",
        origin: UrlHelper.absolute(old_url),
        for_site_setting: true
      ).create_for(Discourse.system_user.id)

      SiteSetting.public_send("#{new_setting}=", upload)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def logger
    Rails.logger
  end
end
