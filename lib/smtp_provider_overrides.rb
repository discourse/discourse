# frozen_string_literal: true

class SmtpProviderOverrides
  # Ideally we (or net-smtp) would automatically detect the correct authentication
  # method, but this is sufficient for our purposes because we know certain providers
  # need certain authentication methods. This may need to change when we start to
  # use XOAUTH2 for SMTP.
  def self.authentication_override(host)
    return "login" if %w[smtp.office365.com smtp-mail.outlook.com].include?(host)
    GlobalSetting.smtp_authentication
  end
end
