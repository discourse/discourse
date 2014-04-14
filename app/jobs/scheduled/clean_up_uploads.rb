module Jobs

  class CleanUpUploads < Jobs::Scheduled
    every 1.hour

    def execute(args)
      return unless SiteSetting.clean_up_uploads?

      uploads_used_in_posts = PostUpload.uniq.pluck(:upload_id)
      uploads_used_as_avatars = User.uniq.where('uploaded_avatar_id IS NOT NULL').pluck(:uploaded_avatar_id)
      uploads_used_as_profile_backgrounds = User.uniq.where("profile_background IS NOT NULL AND profile_background != ''").pluck(:profile_background)
      
      grace_period = [SiteSetting.clean_orphan_uploads_grace_period_hours, 1].max

      Upload.where("created_at < ?", grace_period.hour.ago)
            .where("id NOT IN (?)", uploads_used_in_posts + uploads_used_as_avatars)
            .where("url NOT IN (?)", uploads_used_as_profile_backgrounds)
            .find_each do |upload|
        upload.destroy
      end

    end

  end

end
