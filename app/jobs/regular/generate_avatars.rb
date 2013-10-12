require "image_sorcery"

module Jobs

  class GenerateAvatars < Jobs::Base

    def execute(args)
      upload_id = args[:upload_id]
      raise Discourse::InvalidParameters.new(:upload_id) unless upload_id.present?

      user_id = args[:user_id]
      raise Discourse::InvalidParameters.new(:user_id) unless user_id.present?

      upload = Upload.where(id: upload_id).first
      user = User.where(id: user_id).first
      return unless upload.present? || user.present?

      external_copy = Discourse.store.download(upload) if Discourse.store.external?
      original_path = if Discourse.store.external?
        external_copy.path
      else
        Discourse.store.path_for(upload)
      end

      # we'll extract the first frame when it's a gif
      source = original_path
      source << "[0]" unless SiteSetting.allow_animated_avatars

      [120, 45, 32, 25, 20].each do |s|
        # handle retina too
        [s, s * 2].each do |size|
          # create a temp file with the same extension as the original
          temp_file = Tempfile.new(["discourse-avatar", File.extname(original_path)])
          temp_path = temp_file.path
          # create a centered square thumbnail
          if ImageSorcery.new(source).convert(temp_path, gravity: "center", thumbnail: "#{size}x#{size}^", extent: "#{size}x#{size}", background: "transparent")
            Discourse.store.store_avatar(temp_file, upload, size)
          end
          # close && remove temp file
          temp_file.close!
        end
      end

      # make sure we remove the cached copy from external stores
      external_copy.close! if Discourse.store.external?

      # attach the avatar to the user
      user.uploaded_avatar_template = Discourse.store.absolute_avatar_template(upload)
      user.save!

    end

  end

end
