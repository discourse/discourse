# frozen_string_literal: true

module Chat
  class AllowUploadsValidator
    def initialize(opts = {})
      @opts = opts
    end

    def valid_value?(value)
      return false if value == "t" && prevent_enabling_chat_uploads?
      true
    end

    def error_message
      if prevent_enabling_chat_uploads?
        I18n.t("site_settings.errors.chat_upload_not_allowed_secure_uploads")
      end
    end

    def prevent_enabling_chat_uploads?
      SiteSetting.secure_uploads && !GlobalSetting.allow_unsecure_chat_uploads
    end
  end
end
