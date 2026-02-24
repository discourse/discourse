# frozen_string_literal: true

class ProblemCheck::MissingMailgunApiKey < ProblemCheck
  self.priority = "low"

  def call
    return no_problem if !SiteSetting.reply_by_email_enabled
    return no_problem if ActionMailer::Base.smtp_settings[:address] != "smtp.mailgun.org"
    return no_problem if SiteSetting.mailgun_api_key.present?

    problem
  end
end
