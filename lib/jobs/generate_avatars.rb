require "image_sorcery"

module Jobs

  class GenerateAvatars < Jobs::Base

    def execute(args)
      upload = Upload.where(id: args[:upload_id]).first
      return unless upload.present?

      external_copy = Discourse.store.download(upload) if Discourse.store.external?
      original_path = if Discourse.store.external?
        external_copy.path
      else
        Discourse.store.path_for(upload)
      end

      [120, 45, 32, 25, 20].each do |s|
        # handle retina too
        [s, s * 2].each do |size|
          # create a temp file with the same extension as the original
          temp_file = Tempfile.new(["discourse-avatar", File.extname(original_path)])
          temp_path = temp_file.path
          #
          Discourse.store.store_avatar(temp_file, upload, size) if ImageSorcery.new(original_path).convert(temp_path, gravity: "center", thumbnail: "#{size}x#{size}^", extent: "#{size}x#{size}")
          # close && remove temp file
          temp_file.close!
        end
      end

      # make sure we remove the cached copy from external stores
      external_copy.close! if Discourse.store.external?

      user = User.where(id: upload.user_id).first
      user.uploaded_avatar_template = Discourse.store.absolute_avatar_template(upload)
      user.save!

    end

  end

end
