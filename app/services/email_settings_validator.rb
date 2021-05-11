# frozen_string_literal: true

class EmailSettingsValidator
  def self.friendly_exception_message(exception)
    case exception
    when Net::POPAuthenticationError
      "There was an issue with the POP3 credentials provided, check the username and password and try again."
    when Net::IMAP::NoResponseError
      # Most of IMAP's errors are lumped under here, including invalid
      # credentials errors, because it is raised when a "NO" response is
      # raised from the IMAP server https://datatracker.ietf.org/doc/html/rfc3501#section-7.1.2
      #
      # Generally, it should be fairly safe to just return the error message as is.

      if exception.message.match(/Invalid credentials/)
        return "There was an issue with the IMAP credentials provided, check the username and password and try again."
      end

      "An error occurred when communicating with the IMAP server. " + exception.message.gsub(" (Failure)", "")

      # special case for bad creds
    when Net::SMTPAuthenticationError
      "There was an issue with the SMTP credentials provided, check the username and password and try again."
    when Net::SMTPServerBusy
      "The SMTP server is currently busy, try again later."
    when Net::SMTPSyntaxError, Net::SMTPFatalError, Net::SMTPUnknownError
      "There was an unhandled error when communicating with the SMTP server. " + exception.message
    when SocketError, Errno::ECONNREFUSED
      "There was an issue connecting with the server, check the server name and port and try again."
    when Net::OpenTimeout, Net::ReadTimeout
      "Connection to the server timed out, check the server name and port and try again."
    else
      "Unhandled error when testing email settings. " + exception.message
    end
  end

  def self.validate_pop3(
    host:,
    port:,
    username:,
    password:,
    ssl: SiteSetting.pop3_polling_ssl,
    openssl_verify: SiteSetting.pop3_polling_openssl_verify
  )
    pop3 = Net::POP3.new(host, port)

    # Note that we do not allow which verification mode to be specified
    # like we do for SMTP, we just pick TLS1_2 if the SSL and openSSL verify
    # options have been enabled.
    if ssl
      if openssl_verify
        pop3.enable_ssl(max_version: OpenSSL::SSL::TLS1_2_VERSION)
      else
        pop3.enable_ssl(OpenSSL::SSL::VERIFY_NONE)
      end
    end

    # This disconnects itself, unlike SMTP and IMAP.
    pop3.auth_only(username, password)
  end

  # domain: used for HELO, will be the email sender's domain, so often
  # will just be the host e.g. the domain for test@gmail.com is gmail.com
  def self.validate_smtp(
    host:,
    port:,
    domain:,
    username:,
    password:,
    authentication: GlobalSetting.smtp_authentication,
    enable_starttls_auto: GlobalSetting.smtp_enable_start_tls,
    enable_tls: GlobalSetting.smtp_force_tls,
    openssl_verify_mode: GlobalSetting.smtp_openssl_verify_mode
  )
    if enable_tls && enable_starttls_auto
      raise ArgumentError, "TLS and STARTTLS are mutually exclusive"
    end

    if ![:plain, :login, :cram_md5].include?(authentication.to_sym)
      raise ArgumentError, "Invalid authentication method. Must be plain, login, or cram_md5."
    end

    if Rails.env.development? && domain.blank?
      domain = "localhost"
    end

    smtp = Net::SMTP.new(host, port)

    # These SSL options are cribbed from the Mail gem, which is used internally
    # by ActionMailer. Unfortunately the mail gem hides this setup in private
    # methods, e.g. https://github.com/mikel/mail/blob/master/lib/mail/network/delivery_methods/smtp.rb#L112-L147
    #
    # Relying on the GlobalSetting options is a good idea here.
    #
    # For specific use cases, options should be passed in from higher up. For example
    # Gmail needs either port 465 and tls enabled, or port 587 and starttls_auto.
    if openssl_verify_mode.kind_of?(String)
      openssl_verify_mode = OpenSSL::SSL.const_get("VERIFY_#{openssl_verify_mode.upcase}")
    end
    ssl_context = Net::SMTP.default_ssl_context
    ssl_context.verify_mode = openssl_verify_mode if openssl_verify_mode

    smtp.enable_starttls_auto(ssl_context) if enable_starttls_auto
    smtp.enable_tls(ssl_context) if enable_tls

    smtp.start(domain, username, password, authentication.to_sym)
    smtp.finish
  end

  def self.validate_imap(
    host:,
    port:,
    username:,
    password:,
    open_timeout: 10,
    ssl: true
  )
    imap = Net::IMAP.new(host, port: port, ssl: ssl, open_timeout: open_timeout)
    imap.login(username, password)
    imap.logout rescue nil
    imap.disconnect
  end
end
