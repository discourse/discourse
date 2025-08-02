# frozen_string_literal: true

module Chat
  class DirectMessageEnabledGroupsValidator
    def initialize(opts = {})
      @opts = opts
    end

    def valid_value?(val)
      val.present? && val != ""
    end

    def error_message
      I18n.t("site_settings.errors.direct_message_enabled_groups_invalid")
    end
  end
end
