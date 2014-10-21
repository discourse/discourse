module Jobs

  class CleanUpUploads < Jobs::Scheduled
    every 1.hour

    def execute(args)
      return unless SiteSetting.clean_up_uploads?

      ignore_urls = []
      ignore_urls << UserProfile.uniq.where("profile_background IS NOT NULL AND profile_background != ''").pluck(:profile_background)
      ignore_urls << UserProfile.uniq.where("card_background IS NOT NULL AND card_background != ''").pluck(:card_background)
      ignore_urls << Category.uniq.where("logo_url IS NOT NULL AND logo_url != ''").pluck(:logo_url)
      ignore_urls << Category.uniq.where("background_url IS NOT NULL AND background_url != ''").pluck(:background_url)
      ignore_urls.flatten!

      grace_period = [SiteSetting.clean_orphan_uploads_grace_period_hours, 1].max

      Upload.where("created_at < ? AND
                   (retain_hours IS NULL OR created_at < current_timestamp - interval '1 hour' * retain_hours )", grace_period.hour.ago)
            .where("id NOT IN (SELECT upload_id from post_uploads)")
            .where("id NOT IN (SELECT custom_upload_id from user_avatars)")
            .where("id NOT IN (SELECT gravatar_upload_id from user_avatars)")
            .where("url NOT IN (?)", ignore_urls)
            .find_each do |upload|
        upload.destroy
      end

    end

  end

end
