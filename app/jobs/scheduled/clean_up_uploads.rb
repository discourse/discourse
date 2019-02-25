module Jobs
  class CleanUpUploads < Jobs::Scheduled
    every 1.hour

    def execute(args)
      grace_period = [SiteSetting.clean_orphan_uploads_grace_period_hours, 1].max

      # always remove invalid upload records
      Upload
        .where("retain_hours IS NULL OR created_at < current_timestamp - interval '1 hour' * retain_hours")
        .where("created_at < ?", grace_period.hour.ago)
        .where(url: "")
        .find_each(&:destroy!)

      return unless SiteSetting.clean_up_uploads?

      base_url = Discourse.store.internal? ? Discourse.store.relative_base_url : Discourse.store.absolute_base_url
      s3_hostname = URI.parse(base_url).hostname
      s3_cdn_hostname = URI.parse(SiteSetting.Upload.s3_cdn_url || "").hostname

      # Any URLs in site settings are fair game
      ignore_urls = [
        SiteSetting.logo_url(warn: false),
        SiteSetting.logo_small_url(warn: false),
        SiteSetting.digest_logo_url(warn: false),
        SiteSetting.mobile_logo_url(warn: false),
        SiteSetting.large_icon_url(warn: false),
        SiteSetting.favicon_url(warn: false),
        SiteSetting.default_opengraph_image_url(warn: false),
        SiteSetting.twitter_summary_large_image_url(warn: false),
        SiteSetting.apple_touch_icon_url(warn: false),
        *SiteSetting.selectable_avatars.split("\n"),
      ].flatten.map do |url|
        if url.present?
          url = url.dup

          if s3_cdn_hostname.present? && s3_hostname.present?
            url.gsub!(s3_cdn_hostname, s3_hostname)
          end

          url[base_url] && url[url.index(base_url)..-1]
        else
          nil
        end
      end.compact.uniq

      result = Upload.where("uploads.retain_hours IS NULL OR uploads.created_at < current_timestamp - interval '1 hour' * uploads.retain_hours")
        .where("uploads.created_at < ?", grace_period.hour.ago)
        .joins(<<~SQL)
          LEFT JOIN site_settings ss
          ON NULLIF(ss.value, '')::integer = uploads.id
          AND ss.data_type = #{SiteSettings::TypeSupervisor.types[:upload].to_i}
        SQL
        .joins("LEFT JOIN post_uploads pu ON pu.upload_id = uploads.id")
        .joins("LEFT JOIN users u ON u.uploaded_avatar_id = uploads.id")
        .joins("LEFT JOIN user_avatars ua ON ua.gravatar_upload_id = uploads.id OR ua.custom_upload_id = uploads.id")
        .joins("LEFT JOIN user_profiles up ON up.profile_background = uploads.url OR up.card_background = uploads.url")
        .joins("LEFT JOIN categories c ON c.uploaded_logo_id = uploads.id OR c.uploaded_background_id = uploads.id")
        .joins("LEFT JOIN custom_emojis ce ON ce.upload_id = uploads.id")
        .joins("LEFT JOIN theme_fields tf ON tf.upload_id = uploads.id")
        .joins("LEFT JOIN user_exports ue ON ue.upload_id = uploads.id")
        .where("pu.upload_id IS NULL")
        .where("u.uploaded_avatar_id IS NULL")
        .where("ua.gravatar_upload_id IS NULL AND ua.custom_upload_id IS NULL")
        .where("up.profile_background IS NULL AND up.card_background IS NULL")
        .where("c.uploaded_logo_id IS NULL AND c.uploaded_background_id IS NULL")
        .where("ce.upload_id IS NULL")
        .where("tf.upload_id IS NULL")
        .where("ue.upload_id IS NULL")
        .where("ss.value IS NULL")

      result = result.where("uploads.url NOT IN (?)", ignore_urls) if ignore_urls.present?

      result.find_each do |upload|
        if upload.sha1.present?
          encoded_sha = Base62.encode(upload.sha1.hex)
          next if QueuedPost.where("raw LIKE '%#{upload.sha1}%' OR raw LIKE '%#{encoded_sha}%'").exists?
          next if Draft.where("data LIKE '%#{upload.sha1}%' OR data LIKE '%#{encoded_sha}%'").exists?
          upload.destroy
        else
          upload.delete
        end
      end
    end
  end
end
