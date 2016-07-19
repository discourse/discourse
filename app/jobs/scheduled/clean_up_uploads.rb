module Jobs
  class CleanUpUploads < Jobs::Scheduled
    every 1.hour

    def execute(args)
      return unless SiteSetting.clean_up_uploads?

      ignore_urls = []
      ignore_urls |= UserProfile.uniq.select(:profile_background).where("profile_background IS NOT NULL AND profile_background != ''").pluck(:profile_background)
      ignore_urls |= UserProfile.uniq.select(:card_background).where("card_background IS NOT NULL AND card_background != ''").pluck(:card_background)
      ignore_urls |= Category.uniq.select(:logo_url).where("logo_url IS NOT NULL AND logo_url != ''").pluck(:logo_url)
      ignore_urls |= Category.uniq.select(:background_url).where("background_url IS NOT NULL AND background_url != ''").pluck(:background_url)

      ids = []
      ids |= PostUpload.uniq.select(:upload_id).pluck(:upload_id)
      ids |= User.uniq.select(:uploaded_avatar_id).where("uploaded_avatar_id IS NOT NULL").pluck(:uploaded_avatar_id)
      ids |= UserAvatar.uniq.select(:gravatar_upload_id).where("gravatar_upload_id IS NOT NULL").pluck(:gravatar_upload_id)

      grace_period = [SiteSetting.clean_orphan_uploads_grace_period_hours, 1].max

      result = Upload.where("created_at < ?", grace_period.hour.ago)
                     .where("retain_hours IS NULL OR created_at < current_timestamp - interval '1 hour' * retain_hours")

      if !ids.empty?
        result = result.where("id NOT IN (?)", ids)
      end

      if !ignore_urls.empty?
        result = result.where("url NOT IN (?)", ignore_urls)
      end

      result.find_each { |upload| upload.destroy }
    end
  end
end
