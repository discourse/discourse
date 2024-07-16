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

  def self.ssl_override(host, port, enable_tls, enable_starttls_auto)
    # Certain mail servers act weirdly if you do not use the correct combinations of
    # TLS settings based on the port, we clean these up here for the user.
    if %w[smtp.gmail.com smtp.office365.com smtp-mail.outlook.com].include?(host)
      if port.to_i == 587
        enable_starttls_auto = true
        enable_tls = false
      elsif port.to_i == 465
        enable_starttls_auto = false
        enable_tls = true
      end
    end

    [port, enable_tls, enable_starttls_auto]
  end
end
