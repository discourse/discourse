module Jobs

  class CreateAvatarThumbnails < Jobs::Base

    def execute(args)
      return if Rails.env.test?
      upload_id = args[:upload_id]

      raise Discourse::InvalidParameters.new(:upload_id) if upload_id.blank?

      return unless upload = Upload.find_by(id: upload_id)
      return unless user = User.find_by(id: args[:user_id] || upload.user_id)

      Discourse.avatar_sizes.each do |size|
        OptimizedImage.create_for(upload, size, size, filename: upload.original_filename, allow_animation: SiteSetting.allow_animated_avatars)
      end
    end

  end

end
