module Jobs

  class CreateThumbnails < Jobs::Base

    def execute(args)
      upload_id = args[:upload_id]
      type = args[:type]

      raise Discourse::InvalidParameters.new(:upload_id) if upload_id.blank?
      raise Discourse::InvalidParameters.new(:type) if type.blank?

      # only need to generate thumbnails for avatars
      return if type != "avatar"

      upload = Upload.find(upload_id)

      self.send("create_thumbnails_for_#{type}", upload)
    end

    def create_thumbnails_for_avatar(upload)
      Discourse.avatar_sizes.each do |size|
        OptimizedImage.create_for(upload, size, size, allow_animation: SiteSetting.allow_animated_avatars)
      end
    end

  end

end
