module Jobs

  class CleanUpUploads < Jobs::Scheduled
    every 1.hour

    def execute(args)
      return unless SiteSetting.clean_up_uploads?

      grace_period = [SiteSetting.clean_orphan_uploads_grace_period_hours, 1].max

      Upload.where("created_at < ?", grace_period.hour.ago)
            .where("retain_hours IS NULL OR created_at < current_timestamp - interval '1 hour' * retain_hours")
            .where("id NOT IN (SELECT upload_id FROM post_uploads WHERE upload_id IS NOT NULL)")
            .where("id NOT IN (SELECT uploaded_avatar_id FROM users WHERE uploaded_avatar_id IS NOT NULL)")
            .where("id NOT IN (SELECT gravatar_upload_id FROM user_avatars WHERE gravatar_upload_id IS NOT NULL)")
            .where("url NOT IN (SELECT profile_background FROM user_profiles WHERE LENGTH(COALESCE(profile_background, '')) > 0)")
            .where("url NOT IN (SELECT card_background FROM user_profiles WHERE LENGTH(COALESCE(card_background, '')) > 0)")
            .where("url NOT IN (SELECT logo_url FROM categories WHERE LENGTH(COALESCE(logo_url, '')) > 0)")
            .where("url NOT IN (SELECT background_url FROM categories WHERE LENGTH(COALESCE(background_url, '')) > 0)")
            .destroy_all
    end

  end

end
