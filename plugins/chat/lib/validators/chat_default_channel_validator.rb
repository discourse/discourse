# frozen_string_literal: true

class ChatDefaultChannelValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(value)
    !!(value == "" || ChatChannel.find_by(id: value.to_i)&.public_channel?)
  end

  def error_message
    I18n.t("site_settings.errors.chat_default_channel")
  end
end
