module Jobs

  class CreateThumbnails < Jobs::Base

    def execute(args)
      type = args[:type]
      upload_id = args[:upload_id]

      raise Discourse::InvalidParameters.new(:upload_id) if upload_id.blank?
      raise Discourse::InvalidParameters.new(:type) if type.blank?

      # only need to generate thumbnails for avatars
      return if type != "avatar"

      upload = Upload.find(upload_id)

      user_id = args[:user_id] || upload.user_id
      user = User.find(user_id)

      self.send("create_thumbnails_for_#{type}", upload, user)
    end

    def create_thumbnails_for_avatar(upload, user)
      UserAvatar.create_thumbnails(upload, user)
    end

  end

end
