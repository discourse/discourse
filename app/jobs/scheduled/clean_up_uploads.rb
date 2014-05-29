module Jobs

  class CleanUpUploads < Jobs::Scheduled
    every 1.hour

    def execute(args)
      return unless SiteSetting.clean_up_uploads?

      uploads_used_as_profile_backgrounds = User.uniq.where("profile_background IS NOT NULL AND profile_background != ''").pluck(:profile_background)

      grace_period = [SiteSetting.clean_orphan_uploads_grace_period_hours, 1].max

      Upload.where("created_at < ?", grace_period.hour.ago)
            .where("id NOT IN (SELECT upload_id from post_uploads)")
            .where("id NOT IN (SELECT system_upload_id from post_uploads)")
            .where("id NOT IN (SELECT custom_upload_id from post_uploads)")
            .where("id NOT IN (SELECT gravatar_upload_id from post_uploads)")
            .where("url NOT IN (?)", uploads_used_as_profile_backgrounds)
            .find_each do |upload|
        upload.destroy
      end

    end

  end

end
