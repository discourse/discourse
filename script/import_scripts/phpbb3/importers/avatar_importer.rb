module ImportScripts::PhpBB3
  class AvatarImporter
    # @param uploader [ImportScripts::Uploader]
    # @param settings [ImportScripts::PhpBB3::Settings]
    # @param phpbb_config [Hash]
    def initialize(uploader, settings, phpbb_config)
      @uploader = uploader
      @settings = settings

      @uploaded_avatar_path = File.join(settings.base_dir, phpbb_config[:avatar_path])
      @gallery_path = File.join(settings.base_dir, phpbb_config[:avatar_gallery_path])
      @avatar_salt = phpbb_config[:avatar_salt]
    end

    def import_avatar(user, row)
      avatar_type = row[:user_avatar_type]
      return unless is_avatar_importable?(user, avatar_type)

      filename = row[:user_avatar]
      path = get_avatar_path(avatar_type, filename)
      return if path.nil?

      begin
        filename = "avatar#{File.extname(path)}"
        upload = @uploader.create_upload(user.id, path, filename)

        if upload.present? && upload.persisted?
          user.import_mode = false
          user.create_user_avatar
          user.import_mode = true
          user.user_avatar.update(custom_upload_id: upload.id)
          user.update(uploaded_avatar_id: upload.id)
        else
          puts "Failed to upload avatar for user #{user.username}: #{path}"
          puts upload.errors.inspect if upload
        end
      rescue SystemCallError => err
        Rails.logger.error("Could not import avatar for user #{user.username}: #{err.message}")
      end
    end

    protected

    def is_avatar_importable?(user, avatar_type)
      is_allowed_avatar_type?(avatar_type) && user.uploaded_avatar_id.blank?
    end

    def get_avatar_path(avatar_type, filename)
      case avatar_type
      when Constants::AVATAR_TYPE_UPLOADED, Constants::AVATAR_TYPE_STRING_UPLOADED then
        filename.gsub!(/_[0-9]+\./, '.') # we need 1337.jpg, not 1337_2983745.jpg
          get_uploaded_path(filename)
      when Constants::AVATAR_TYPE_GALLERY, Constants::AVATAR_TYPE_STRING_GALLERY then
        get_gallery_path(filename)
      when Constants::AVATAR_TYPE_REMOTE, Constants::AVATAR_TYPE_STRING_REMOTE then
        download_avatar(filename)
      else
        puts "Invalid avatar type #{avatar_type}. Skipping..."
        nil
      end
    end

    # Tries to download the remote avatar.
    def download_avatar(url)
      max_image_size_kb = SiteSetting.max_image_size_kb.kilobytes

      begin
        avatar_file = FileHelper.download(
          url,
          max_file_size: max_image_size_kb,
          tmp_file_name: 'discourse-avatar'
        )
      rescue StandardError => err
        warn "Error downloading avatar: #{err.message}. Skipping..."
        return nil
      end

      if avatar_file
        if avatar_file.size <= max_image_size_kb
          return avatar_file
        else
          return nil
        end
      end

      Rails.logger.error("There was an error while downloading '#{url}' locally.")
      nil
    end

    def get_uploaded_path(filename)
      File.join(@uploaded_avatar_path, "#{@avatar_salt}_#{filename}")
    end

    def get_gallery_path(filename)
      File.join(@gallery_path, filename)
    end

    def is_allowed_avatar_type?(avatar_type)
      case avatar_type
      when Constants::AVATAR_TYPE_UPLOADED, Constants::AVATAR_TYPE_STRING_UPLOADED then
        @settings.import_uploaded_avatars
      when Constants::AVATAR_TYPE_REMOTE, Constants::AVATAR_TYPE_STRING_REMOTE then
        @settings.import_remote_avatars
      when Constants::AVATAR_TYPE_GALLERY, Constants::AVATAR_TYPE_STRING_GALLERY then
        @settings.import_gallery_avatars
      else
        false
      end
    end
  end
end
