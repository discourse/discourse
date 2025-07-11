# frozen_string_literal: true

class ChatIntegrationSlackEnabledSettingValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    return true if val == ("f") || val == (false)
    if SiteSetting.chat_integration_slack_outbound_webhook_url.blank? &&
         SiteSetting.chat_integration_slack_access_token.blank?
      return false
    end
    true
  end

  def error_message
    I18n.t("site_settings.errors.chat_integration_slack_api_configs_are_empty")
  end
end
