# frozen_string_literal: true

class ProblemCheck::TelegramWebhookSecretMissing < ProblemCheck
  self.priority = "low"

  def call
    return no_problem if !SiteSetting.chat_integration_enabled
    return no_problem if !SiteSetting.chat_integration_telegram_enabled
    return no_problem if !SiteSetting.chat_integration_telegram_enable_slash_commands
    return no_problem if SiteSetting.chat_integration_telegram_secret.present?

    problem
  end
end
