# frozen_string_literal: true

class ProblemCheck::EmailBounceHandling < ProblemCheck
  self.priority = "low"

  PROVIDERS = [
    { address: "smtp.mailgun.org", setting: :mailgun_api_key, name: "Mailgun" },
    { address: "smtp.sendgrid.net", setting: :sendgrid_verification_key, name: "SendGrid" },
    { address: /\.mailjet\.com\z/, setting: :mailjet_webhook_token, name: "Mailjet" },
    { address: "smtp.mandrillapp.com", setting: :mandrill_authentication_key, name: "Mandrill" },
    { address: "smtp.postmarkapp.com", setting: :postmark_webhook_token, name: "Postmark" },
    { address: "smtp.sparkpostmail.com", setting: :sparkpost_webhook_token, name: "SparkPost" },
    { address: "smtp.mailpace.com", setting: :mailpace_verification_key, name: "Mailpace" },
    { address: /email-smtp\..+\.amazonaws\.com\z/, name: "AWS SES" },
  ].freeze

  def call
    if SiteSetting.reply_by_email_enabled && Email::Sender.bounceable_reply_address?
      return no_problem
    end

    smtp_address = ActionMailer::Base.smtp_settings[:address].to_s

    if provider = PROVIDERS.find { |p| p[:address] === smtp_address }
      return no_problem if provider[:setting].blank?
      return no_problem if SiteSetting.public_send(provider[:setting]).present?

      problem(
        override_key: "dashboard.problem.email_bounce_handling.webhook_key_missing",
        override_data: {
          provider: provider[:name],
          setting: provider[:setting],
        },
      )
    else
      problem(override_key: "dashboard.problem.email_bounce_handling.no_bounce_handling")
    end
  end
end
