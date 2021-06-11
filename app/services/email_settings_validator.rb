# frozen_string_literal: true

require 'net/imap'
require 'net/smtp'
require 'net/pop'

# Usage:
#
# begin
#   EmailSettingsValidator.validate_imap(host: "imap.test.com", port: 999, username: "test@test.com", password: "password")
#
#   # or for specific host preset
#   EmailSettingsValidator.validate_imap(**{ username: "test@gmail.com", password: "test" }.merge(Email.gmail_imap_settings))
#
# rescue *EmailSettingsExceptionHandler::EXPECTED_EXCEPTIONS => err
#   EmailSettingsExceptionHandler.friendly_exception_message(err, host)
# end
class EmailSettingsValidator
  def self.validate_as_user(user, protocol, **kwargs)
    DistributedMutex.synchronize("validate_#{protocol}_#{user.id}", validity: 10) do
      self.public_send("validate_#{protocol}", **kwargs)
    end
  end

  ##
  # Attempts to authenticate and disconnect a POP3 session and if that raises
  # an error then it is assumed the credentials or some other settings are wrong.
  #
  # @param debug [Boolean] - When set to true, any errors will be logged at a warning
  #                          level before being re-raised.
  def self.validate_pop3(
    host:,
    port:,
    username:,
    password:,
    ssl: SiteSetting.pop3_polling_ssl,
    openssl_verify: SiteSetting.pop3_polling_openssl_verify,
    debug: Rails.env.development?
  )
    begin
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
    rescue => err
      log_and_raise(err, debug)
    end
  end

  ##
  # Attempts to start an SMTP session and if that raises an error then it is
  # assumed the credentials or other settings are wrong.
  #
  # For Gmail, the port should be 587, enable_starttls_auto should be true,
  # and enable_tls should be false.
  #
  # @param domain [String] - Used for HELO, will be the email sender's domain, so often
  #                          will just be the host e.g. the domain for test@gmail.com is gmail.com.
  #                          localhost can be used in development mode.
  #                          See https://datatracker.ietf.org/doc/html/rfc788#section-4
  # @param debug [Boolean] - When set to true, any errors will be logged at a warning
  #                          level before being re-raised.
  def self.validate_smtp(
    host:,
    port:,
    username:,
    password:,
    domain: nil,
    authentication: GlobalSetting.smtp_authentication,
    enable_starttls_auto: GlobalSetting.smtp_enable_start_tls,
    enable_tls: GlobalSetting.smtp_force_tls,
    openssl_verify_mode: GlobalSetting.smtp_openssl_verify_mode,
    debug: Rails.env.development?
  )
    begin
      port, enable_tls, enable_starttls_auto = provider_specific_ssl_overrides(
        host, port, enable_tls, enable_starttls_auto
      )

      if enable_tls && enable_starttls_auto
        raise ArgumentError, "TLS and STARTTLS are mutually exclusive"
      end

      if ![:plain, :login, :cram_md5].include?(authentication.to_sym)
        raise ArgumentError, "Invalid authentication method. Must be plain, login, or cram_md5."
      end

      if domain.blank?
        if Rails.env.development?
          domain = "localhost"
        else

          # Because we are using the SMTP settings here to send emails,
          # the domain should just be the TLD of the host.
          domain = MiniSuffix.domain(host)
        end
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

      smtp.open_timeout = 5
      smtp.read_timeout = 5

      smtp.start(domain, username, password, authentication.to_sym)
      smtp.finish
    rescue => err
      log_and_raise(err, debug)
    end
  end

  ##
  # Attempts to login, logout, and disconnect an IMAP session and if that raises
  # an error then it is assumed the credentials or some other settings are wrong.
  #
  # @param debug [Boolean] - When set to true, any errors will be logged at a warning
  #                          level before being re-raised.
  def self.validate_imap(
    host:,
    port:,
    username:,
    password:,
    open_timeout: 5,
    ssl: true,
    debug: false
  )
    begin
      imap = Net::IMAP.new(host, port: port, ssl: ssl, open_timeout: open_timeout)
      imap.login(username, password)
      imap.logout rescue nil
      imap.disconnect
    rescue => err
      log_and_raise(err, debug)
    end
  end

  def self.log_and_raise(err, debug)
    if debug
      Rails.logger.warn("[EmailSettingsValidator] Error encountered when validating email settings: #{err.message} #{err.backtrace.join("\n")}")
    end
    raise err
  end

  def self.provider_specific_ssl_overrides(host, port, enable_tls, enable_starttls_auto)
    # Gmail acts weirdly if you do not use the correct combinations of
    # TLS settings based on the port, we clean these up here for the user.
    if host == "smtp.gmail.com"
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
