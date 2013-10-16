module Jobs

  class CleanUpUploads < Jobs::Scheduled
    recurrence { hourly }

    def execute(args)
      return unless SiteSetting.clean_up_uploads?

      uploads_used_in_posts = PostUpload.uniq.pluck(:upload_id)
      uploads_used_as_avatars = User.uniq.where('uploaded_avatar_id IS NOT NULL').pluck(:uploaded_avatar_id)

      grace_period = [SiteSetting.uploads_grace_period_in_hours, 1].max

      Upload.where("created_at < ?", grace_period.hour.ago)
            .where("id NOT IN (?)", uploads_used_in_posts + uploads_used_as_avatars)
            .find_each do |upload|
        upload.destroy
      end

    end

  end

end
