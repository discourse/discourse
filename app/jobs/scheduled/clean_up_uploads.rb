module Jobs
  class CleanUpUploads < Jobs::Scheduled
    every 1.hour

    def execute(args)
      return unless SiteSetting.clean_up_uploads?

      ignore_urls  = []
      ignore_urls |= UserProfile.uniq.where("profile_background IS NOT NULL AND profile_background != ''").pluck(:profile_background)
      ignore_urls |= UserProfile.uniq.where("card_background IS NOT NULL AND card_background != ''").pluck(:card_background)
      ignore_urls |= Category.uniq.where("logo_url IS NOT NULL AND logo_url != ''").pluck(:logo_url)
      ignore_urls |= Category.uniq.where("background_url IS NOT NULL AND background_url != ''").pluck(:background_url)

      # Any URLs in site settings are fair game
      ignore_urls |= [SiteSetting.logo_url, SiteSetting.logo_small_url, SiteSetting.favicon_url,
                      SiteSetting.apple_touch_icon_url]

      ids  = []
      ids |= PostUpload.uniq.pluck(:upload_id)
      ids |= User.uniq.where("uploaded_avatar_id IS NOT NULL").pluck(:uploaded_avatar_id)
      ids |= UserAvatar.uniq.where("gravatar_upload_id IS NOT NULL").pluck(:gravatar_upload_id)

      grace_period = [SiteSetting.clean_orphan_uploads_grace_period_hours, 1].max

      result = Upload.where("retain_hours IS NULL OR created_at < current_timestamp - interval '1 hour' * retain_hours")
      result = result.where("created_at < ?", grace_period.hour.ago)
      result = result.where("id NOT IN (?)", ids) if !ids.empty?
      result = result.where("url NOT IN (?)", ignore_urls) if !ignore_urls.empty?

      result.find_each do |upload|
        next if QueuedPost.where("raw LIKE '%#{upload.sha1}%'").exists?
        next if Draft.where("data LIKE '%#{upload.sha1}%'").exists?
        upload.destroy
      end
    end
  end
end
