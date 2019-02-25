module Jobs
  class MigrateUrlSiteSettings < Jobs::Onceoff
    SETTINGS = [
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
    ]

    def execute_onceoff(args)
      SETTINGS.each do |old_setting, new_setting|
        old_url = DB.query_single(
          "SELECT value FROM site_settings WHERE name = '#{old_setting}'"
        ).first

        next if old_url.blank?

        count = 0
        file = nil
        sleep_interval = 5

        loop do
          url = UrlHelper.absolute_without_cdn(old_url)

          begin
            file = FileHelper.download(
              url,
              max_file_size: [
                SiteSetting.max_image_size_kb.kilobytes,
                20.megabytes
              ].max,
              tmp_file_name: 'tmp_site_setting_logo',
              skip_rate_limit: true,
              follow_redirect: true
            )
          rescue OpenURI::HTTPError,
                 OpenSSL::SSL::SSLError,
                 Net::OpenTimeout,
                 Net::ReadTimeout,
                 Errno::ECONNREFUSED,
                 EOFError,
                 SocketError,
                 Discourse::InvalidParameters => e

            logger.warn(
              "Error encountered when trying to download file " +
              "for #{new_setting}.\n#{e.class}: #{e.message}\n#{e.backtrace.join("\n")}"
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

    private

    def logger
      Rails.logger
    end
  end
end
