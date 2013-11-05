require "image_sorcery"

module Jobs

  class GenerateAvatars < Jobs::Base

    def execute(args)
      raise Discourse::ImageMagickMissing.new unless system("command -v convert >/dev/null;")

      upload_id, user_id = args[:upload_id], args[:user_id]
      raise Discourse::InvalidParameters.new(:upload_id) if upload_id.blank?
      raise Discourse::InvalidParameters.new(:user_id) if user_id.blank?

      upload = Upload.where(id: upload_id).first
      user = User.where(id: user_id).first
      return if upload.nil? || user.nil?

      external_copy = Discourse.store.download(upload) if Discourse.store.external?
      original_path = if Discourse.store.external?
        external_copy.path
      else
        Discourse.store.path_for(upload)
      end

      source = original_path
      # extract the first frame when it's a gif
      source << "[0]" unless SiteSetting.allow_animated_avatars
      image = ImageSorcery.new(source)
      extension = File.extname(original_path)

      [120, 45, 32, 25, 20].each do |s|
        # handle retina too
        [s, s * 2].each do |size|
          begin
            # create a temp file with the same extension as the original
            temp_file = Tempfile.new(["discourse-avatar", extension])
            # create a transparent centered square thumbnail
            if image.convert(temp_file.path,
                             gravity: "center",
                             thumbnail: "#{size}x#{size}^",
                             extent: "#{size}x#{size}",
                             background: "transparent")
              if Discourse.store.store_avatar(temp_file, upload, size).blank?
                Rails.logger.error("Failed to store avatar #{size} for #{upload.url} from #{source}")
              end
            else
              Rails.logger.error("Failed to create avatar #{size} for #{upload.url} from #{source}")
            end
          ensure
            # close && remove temp file
            temp_file && temp_file.close!
          end
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
