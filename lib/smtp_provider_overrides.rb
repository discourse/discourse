# frozen_string_literal: true

class SmtpProviderOverrides
  class << self
    # Ideally we (or net-smtp) would automatically detect the correct authentication
    # method, but this is sufficient for our purposes because we know certain providers
    # need certain authentication methods. This may need to change when we start to
    # use XOAUTH2 for SMTP.
    def authentication_override(host)
      if %w[smtp.office365.com smtp-mail.outlook.com smtp.azurecomm.net].include?(host)
        return "login"
      end
      GlobalSetting.smtp_authentication
    end
  end
end
