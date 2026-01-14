# frozen_string_literal: true

module Chat
  class AllowChatInAnonymousModeValidator
    def initialize(opts = {})
      @opts = opts
    end

    def valid_value?(val)
      return true if val == "f"
      return true if SiteSetting.allow_anonymous_mode

      false
    end

    def error_message
      I18n.t("site_settings.errors.allow_chat_in_anonymous_mode_invalid")
    end
  end
end
