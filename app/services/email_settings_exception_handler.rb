# frozen_string_literal: true

require "net/imap"
require "net/smtp"
require "net/pop"

class EmailSettingsExceptionHandler
  EXPECTED_EXCEPTIONS = [
    Net::POPAuthenticationError,
    Net::IMAP::NoResponseError,
    Net::IMAP::Error,
    Net::SMTPAuthenticationError,
    Net::SMTPServerBusy,
    Net::SMTPSyntaxError,
    Net::SMTPFatalError,
    Net::SMTPUnknownError,
    Net::OpenTimeout,
    Net::ReadTimeout,
    SocketError,
    Errno::ECONNREFUSED,
  ].freeze

  class GenericProvider
    def initialize(exception)
      @exception = exception
    end

    def message
      case @exception
      when Net::POPAuthenticationError
        net_pop_authentication_error
      when Net::IMAP::NoResponseError
        net_imap_no_response_error
      when Net::IMAP::Error
        net_imap_unhandled_error
      when Net::SMTPAuthenticationError
        net_smtp_authentication_error
      when Net::SMTPServerBusy
        net_smtp_server_busy
      when Net::SMTPSyntaxError, Net::SMTPFatalError, Net::SMTPUnknownError
        net_smtp_unhandled_error
      when SocketError, Errno::ECONNREFUSED
        socket_connection_error
      when Net::OpenTimeout, Net::ReadTimeout
        net_timeout_error
      else
        unhandled_error
      end
    end

    private

    def net_pop_authentication_error
      I18n.t("email_settings.pop3_authentication_error")
    end

    def net_imap_no_response_error
      # Most of IMAP's errors are lumped under the NoResponseError, including invalid
      # credentials errors, because it is raised when a "NO" response is
      # raised from the IMAP server https://datatracker.ietf.org/doc/html/rfc3501#section-7.1.2
      #
      # Generally, it should be fairly safe to just return the error message as is.
      if @exception.message.match(/Invalid credentials/)
        I18n.t("email_settings.imap_authentication_error")
      else
        I18n.t(
          "email_settings.imap_no_response_error",
          message: @exception.message.gsub(" (Failure)", ""),
        )
      end
    end

    def net_imap_unhandled_error
      I18n.t("email_settings.imap_unhandled_error", message: @exception.message)
    end

    def net_smtp_authentication_error
      # Generally SMTP authentication errors are due to invalid credentials,
      # and most common mail servers provide more detailed error messages,
      # so it should be safe to return the error message as is.
      #
      # Example: Office 365 returns:
      #
      # 535 5.7.139 Authentication unsuccessful, user is locked by your organization's security defaults policy. Contact your administrator.
      #
      # Example: Gmail returns:
      #
      # Application-specific password required. Learn more at https://support.google.com/accounts/answer/185833
      I18n.t("email_settings.smtp_authentication_error", message: @exception.message)
    end

    def net_smtp_server_busy
      I18n.t("email_settings.smtp_server_busy_error")
    end

    def net_smtp_unhandled_error
      I18n.t("email_settings.smtp_unhandled_error", message: @exception.message)
    end

    def socket_connection_error
      I18n.t("email_settings.connection_error")
    end

    def net_timeout_error
      I18n.t("email_settings.timeout_error")
    end

    def unhandled_error
      I18n.t("email_settings.unhandled_error", message: @exception.message)
    end
  end

  def self.friendly_exception_message(exception, host)
    EmailSettingsExceptionHandler::GenericProvider.new(exception).message
  end
end
