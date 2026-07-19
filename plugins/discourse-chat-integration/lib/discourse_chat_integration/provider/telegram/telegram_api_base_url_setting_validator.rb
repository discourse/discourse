# frozen_string_literal: true

require "uri"

class ChatIntegrationTelegramApiBaseUrlSettingValidator
  def initialize(opts = {})
    @opts = opts
  end

  def self.valid_value?(value)
    uri = URI(value)

    uri.is_a?(URI::HTTPS) && uri.host.present? && uri.userinfo.blank? && uri.query.blank? &&
      uri.fragment.blank?
  rescue URI::Error, TypeError
    false
  end

  def valid_value?(value)
    self.class.valid_value?(value)
  end

  def error_message
    I18n.t("site_settings.errors.chat_integration_telegram_api_base_url_invalid")
  end
end
