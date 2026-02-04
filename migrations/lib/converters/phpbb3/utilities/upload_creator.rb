# frozen_string_literal: true

module Migrations::Converters::Phpbb3
  class UploadCreator
    def initialize(phpbb_config: {}, settings: {})
      @phpbb_config = phpbb_config
      @settings = settings
      @base_dir = settings.dig(:phpbb, :base_dir) || ""
    end

    def create_for_attachment(physical_filename:, real_filename:, user_id: nil)
      attachment_path = @phpbb_config[:attachment_path] || "files"
      full_path = File.join(@base_dir, attachment_path, physical_filename)

      return nil unless File.exist?(full_path)

      IntermediateDB::Upload.create_for_file(
        path: full_path,
        filename: real_filename,
        type: "attachment",
        user_id:,
      )
    end

    def create_avatar_for_user(item)
      avatar_type = item[:user_avatar_type]
      avatar_value = item[:user_avatar]

      return nil if avatar_value.blank?

      case avatar_type
      when Constants::AVATAR_TYPE_UPLOADED, Constants::AVATAR_TYPE_STRING_UPLOADED
        create_uploaded_avatar(avatar_value, item[:user_id])
      when Constants::AVATAR_TYPE_REMOTE, Constants::AVATAR_TYPE_STRING_REMOTE
        create_remote_avatar(avatar_value, item[:user_id])
      when Constants::AVATAR_TYPE_GALLERY, Constants::AVATAR_TYPE_STRING_GALLERY
        create_gallery_avatar(avatar_value, item[:user_id])
      end
    end

    private

    def create_uploaded_avatar(avatar_value, user_id)
      avatar_salt = @phpbb_config[:avatar_salt]
      avatar_path = @phpbb_config[:avatar_path] || "images/avatars/upload"

      ext = File.extname(avatar_value)
      filename = "#{avatar_salt}_#{avatar_value.gsub(/\D/, "")}#{ext}"
      full_path = File.join(@base_dir, avatar_path, filename)

      return nil unless File.exist?(full_path)

      IntermediateDB::Upload.create_for_file(path: full_path, type: "avatar", user_id:)
    end

    def create_remote_avatar(url, user_id)
      IntermediateDB::Upload.create_for_url(
        url:,
        filename: File.basename(url),
        type: "avatar",
        user_id:,
      )
    end

    def create_gallery_avatar(avatar_value, user_id)
      gallery_path = @phpbb_config[:avatar_gallery_path] || "images/avatars/gallery"
      full_path = File.join(@base_dir, gallery_path, avatar_value)

      return nil unless File.exist?(full_path)

      IntermediateDB::Upload.create_for_file(path: full_path, type: "avatar", user_id:)
    end
  end
end
