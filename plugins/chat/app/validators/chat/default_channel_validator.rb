# frozen_string_literal: true

module Chat
  class DefaultChannelValidator
    def initialize(opts = {})
      @opts = opts
    end

    def valid_value?(value)
      !!(value == "" || Chat::Channel.find_by(id: value.to_i)&.public_channel?)
    end

    def error_message
      I18n.t("site_settings.errors.chat_default_channel")
    end
  end
end
