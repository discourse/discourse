# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmailSettingsExceptionHandler do
  describe "#friendly_exception_message" do
    it "formats a Net::POPAuthenticationError" do
      exception = Net::POPAuthenticationError.new("invalid credentials")
      expect(subject.class.friendly_exception_message(exception, "pop.test.com")).to eq(
        I18n.t("email_settings.pop3_authentication_error")
      )
    end

    it "formats a Net::IMAP::NoResponseError for invalid credentials" do
      exception = Net::IMAP::NoResponseError.new(stub(data: stub(text: "Invalid credentials")))
      expect(subject.class.friendly_exception_message(exception, "imap.test.com")).to eq(
        I18n.t("email_settings.imap_authentication_error")
      )
    end

    it "formats a general Net::IMAP::NoResponseError" do
      exception = Net::IMAP::NoResponseError.new(stub(data: stub(text: "NO bad problem (Failure)")))
      expect(subject.class.friendly_exception_message(exception, "imap.test.com")).to eq(
        I18n.t("email_settings.imap_no_response_error", message: "NO bad problem")
      )
    end

    it "formats a general Net::IMAP::NoResponseError with application-specific password Gmail error" do
      exception = Net::IMAP::NoResponseError.new(stub(data: stub(text: "NO Application-specific password required")))
      expect(subject.class.friendly_exception_message(exception, "imap.gmail.com")).to eq(
        I18n.t("email_settings.authentication_error_gmail_app_password")
      )
    end

    it "formats a Net::SMTPAuthenticationError" do
      exception = Net::SMTPAuthenticationError.new("invalid credentials")
      expect(subject.class.friendly_exception_message(exception, "smtp.test.com")).to eq(
        I18n.t("email_settings.smtp_authentication_error")
      )
    end

    it "formats a Net::SMTPAuthenticationError with application-specific password Gmail error" do
      exception = Net::SMTPAuthenticationError.new("Application-specific password required")
      expect(subject.class.friendly_exception_message(exception, "smtp.gmail.com")).to eq(
        I18n.t("email_settings.authentication_error_gmail_app_password")
      )
    end

    it "formats a Net::SMTPServerBusy" do
      exception = Net::SMTPServerBusy.new("call me maybe later")
      expect(subject.class.friendly_exception_message(exception, "smtp.test.com")).to eq(
        I18n.t("email_settings.smtp_server_busy_error")
      )
    end

    it "formats a Net::SMTPSyntaxError, Net::SMTPFatalError, and Net::SMTPUnknownError" do
      exception = Net::SMTPSyntaxError.new("bad syntax")
      expect(subject.class.friendly_exception_message(exception, "smtp.test.com")).to eq(
        I18n.t("email_settings.smtp_unhandled_error", message: exception.message)
      )
      exception = Net::SMTPFatalError.new("fatal")
      expect(subject.class.friendly_exception_message(exception, "smtp.test.com")).to eq(
        I18n.t("email_settings.smtp_unhandled_error", message: exception.message)
      )
      exception = Net::SMTPUnknownError.new("unknown")
      expect(subject.class.friendly_exception_message(exception, "smtp.test.com")).to eq(
        I18n.t("email_settings.smtp_unhandled_error", message: exception.message)
      )
    end

    it "formats a SocketError and Errno::ECONNREFUSED" do
      exception = SocketError.new("bad socket")
      expect(subject.class.friendly_exception_message(exception, "smtp.test.com")).to eq(
        I18n.t("email_settings.connection_error")
      )
      exception = Errno::ECONNREFUSED.new("no thanks")
      expect(subject.class.friendly_exception_message(exception, "smtp.test.com")).to eq(
        I18n.t("email_settings.connection_error")
      )
    end

    it "formats a Net::OpenTimeout and Net::ReadTimeout error" do
      exception = Net::OpenTimeout.new("timed out")
      expect(subject.class.friendly_exception_message(exception, "smtp.test.com")).to eq(
        I18n.t("email_settings.timeout_error")
      )
      exception = Net::ReadTimeout.new("timed out")
      expect(subject.class.friendly_exception_message(exception, "smtp.test.com")).to eq(
        I18n.t("email_settings.timeout_error")
      )
    end

    it "formats unhandled errors" do
      exception = StandardError.new("unknown")
      expect(subject.class.friendly_exception_message(exception, "smtp.test.com")).to eq(
        I18n.t("email_settings.unhandled_error", message: exception.message)
      )
    end
  end
end
