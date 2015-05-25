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

    PIXELS ||= [1, 2]

    def create_thumbnails_for_avatar(upload)
      PIXELS.each do |pixel|
        Discourse.avatar_sizes.each do |size|
          size *= pixel
          upload.create_thumbnail!(size, size)
        end
      end
    end

  end

end
