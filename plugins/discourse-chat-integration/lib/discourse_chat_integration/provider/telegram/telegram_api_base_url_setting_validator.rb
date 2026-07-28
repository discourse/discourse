# frozen_string_literal: true

class ChatIntegrationTelegramApiBaseUrlSettingValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(value)
    DiscourseChatIntegration::Provider::TelegramProvider.parse_base_url(value).present?
  end

  def error_message
    I18n.t("site_settings.errors.chat_integration_telegram_api_base_url_invalid")
  end
end
