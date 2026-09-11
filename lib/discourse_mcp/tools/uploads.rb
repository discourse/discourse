# frozen_string_literal: true

require "base64"
require "tempfile"

module DiscourseMcp
  module Tools
    class UploadFile
      UPLOAD_TYPES = %w[avatar profile_background card_background composer].freeze

      def self.call(arguments:, request_context:)
        user = request_context.user or raise Discourse::InvalidAccess
        if UPLOAD_TYPES.exclude?(arguments.fetch("upload_type"))
          raise ToolError, I18n.t("mcp.errors.invalid_upload_type")
        end
        if arguments["user_id"].present? && arguments["user_id"] != user.id
          raise Discourse::InvalidAccess
        end
        validate_source!(arguments)
        validate_avatar!(arguments.fetch("upload_type"), user)

        RateLimiter.new(
          user,
          "uploads-per-minute",
          SiteSetting.max_uploads_per_minute,
          1.minute,
        ).performed!
        file = uploaded_file(arguments)
        upload =
          UploadsController.create_upload(
            current_user: user,
            file:,
            url: arguments["url"],
            type: arguments.fetch("upload_type"),
            for_private_message: false,
            for_site_setting: false,
            pasted: false,
            is_api: true,
            retain_hours: 0,
          )
        if !upload.is_a?(Upload)
          raise ToolError, Array(upload[:errors] || upload["errors"]).join(", ")
        end

        serialized = UploadsController.serialize_upload(upload).deep_symbolize_keys
        ToolHelpers.text_and_structured(
          serialized.slice(
            :id,
            :url,
            :short_url,
            :short_path,
            :original_filename,
            :extension,
            :width,
            :height,
            :filesize,
            :human_filesize,
          ),
        )
      end

      def self.validate_source!(arguments)
        sources = [arguments["image_data"].present?, arguments["url"].present?].count(true)
        if sources != 1 || (arguments["image_data"].present? && arguments["filename"].blank?)
          raise ToolError, I18n.t("mcp.errors.invalid_upload_source")
        end
        return if arguments["url"].blank?

        uri = URI.parse(arguments["url"])
        unless uri.is_a?(URI::HTTP) && uri.host.present? && uri.userinfo.blank?
          raise ToolError, I18n.t("mcp.errors.invalid_upload_url")
        end
      rescue URI::InvalidURIError
        raise ToolError, I18n.t("mcp.errors.invalid_upload_url")
      end
      private_class_method :validate_source!

      def self.validate_avatar!(upload_type, user)
        return if upload_type != "avatar"
        if SiteSetting.discourse_connect_overrides_avatar || SiteSetting.auth_overrides_avatar ||
             !user.in_any_groups?(SiteSetting.uploaded_avatars_allowed_groups_map)
          raise Discourse::InvalidAccess
        end
      end
      private_class_method :validate_avatar!

      def self.uploaded_file(arguments)
        return if arguments["image_data"].blank?

        maximum_size = [
          SiteSetting.max_image_size_kb,
          SiteSetting.max_attachment_size_kb,
        ].max.kilobytes
        encoded = arguments.fetch("image_data")
        if encoded.bytesize > ((maximum_size * 4) / 3) + 4
          raise ToolError, I18n.t("mcp.errors.upload_too_large")
        end
        decoded = Base64.strict_decode64(encoded)
        raise ToolError, I18n.t("mcp.errors.upload_too_large") if decoded.bytesize > maximum_size

        tempfile = Tempfile.new("discourse-mcp-upload")
        tempfile.binmode
        tempfile.write(decoded)
        tempfile.rewind
        ActionDispatch::Http::UploadedFile.new(tempfile:, filename: arguments.fetch("filename"))
      rescue ArgumentError
        raise ToolError, I18n.t("mcp.errors.invalid_upload_data")
      end
      private_class_method :uploaded_file
    end
  end
end
