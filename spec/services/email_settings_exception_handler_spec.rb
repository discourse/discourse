# frozen_string_literal: true

RSpec.describe EmailSettingsExceptionHandler do
  describe "#friendly_exception_message" do
    it "formats a Net::POPAuthenticationError" do
      exception = Net::POPAuthenticationError.new("invalid credentials")
      expect(described_class.friendly_exception_message(exception, "pop.test.com")).to eq(
        I18n.t("email_settings.pop3_authentication_error"),
      )
    end

    it "formats a Net::IMAP::NoResponseError for invalid credentials" do
      exception = Net::IMAP::NoResponseError.new(stub(data: stub(text: "Invalid credentials")))
      expect(described_class.friendly_exception_message(exception, "imap.test.com")).to eq(
        I18n.t("email_settings.imap_authentication_error"),
      )
    end

    it "formats a general Net::IMAP::NoResponseError" do
      exception = Net::IMAP::NoResponseError.new(stub(data: stub(text: "NO bad problem (Failure)")))
      expect(described_class.friendly_exception_message(exception, "imap.test.com")).to eq(
        I18n.t("email_settings.imap_no_response_error", message: "NO bad problem"),
      )
    end

    it "formats a Net::SMTPAuthenticationError" do
      exception = Net::SMTPAuthenticationError.new("invalid credentials")
      expect(described_class.friendly_exception_message(exception, "smtp.test.com")).to eq(
        I18n.t("email_settings.smtp_authentication_error", message: "invalid credentials"),
      )
    end

    it "formats a Net::SMTPServerBusy" do
      exception = Net::SMTPServerBusy.new("call me maybe later")
      expect(described_class.friendly_exception_message(exception, "smtp.test.com")).to eq(
        I18n.t("email_settings.smtp_server_busy_error"),
      )
    end

    it "formats a Net::SMTPSyntaxError, Net::SMTPFatalError, and Net::SMTPUnknownError" do
      exception = Net::SMTPSyntaxError.new(nil, message: "bad syntax")
      expect(described_class.friendly_exception_message(exception, "smtp.test.com")).to eq(
        I18n.t("email_settings.smtp_unhandled_error", message: exception.message),
      )
      exception = Net::SMTPFatalError.new(nil, message: "fatal")
      expect(described_class.friendly_exception_message(exception, "smtp.test.com")).to eq(
        I18n.t("email_settings.smtp_unhandled_error", message: exception.message),
      )
      exception = Net::SMTPUnknownError.new(nil, message: "unknown")
      expect(described_class.friendly_exception_message(exception, "smtp.test.com")).to eq(
        I18n.t("email_settings.smtp_unhandled_error", message: exception.message),
      )
    end

    it "formats a SocketError and Errno::ECONNREFUSED" do
      exception = SocketError.new("bad socket")
      expect(described_class.friendly_exception_message(exception, "smtp.test.com")).to eq(
        I18n.t("email_settings.connection_error"),
      )
      exception = Errno::ECONNREFUSED.new("no thanks")
      expect(described_class.friendly_exception_message(exception, "smtp.test.com")).to eq(
        I18n.t("email_settings.connection_error"),
      )
    end

    it "formats a Net::OpenTimeout and Net::ReadTimeout error" do
      exception = Net::OpenTimeout.new("timed out")
      expect(described_class.friendly_exception_message(exception, "smtp.test.com")).to eq(
        I18n.t("email_settings.timeout_error"),
      )
      exception = Net::ReadTimeout.new("timed out")
      expect(described_class.friendly_exception_message(exception, "smtp.test.com")).to eq(
        I18n.t("email_settings.timeout_error"),
      )
    end

    it "formats unhandled errors" do
      exception = StandardError.new("unknown")
      expect(described_class.friendly_exception_message(exception, "smtp.test.com")).to eq(
        I18n.t("email_settings.unhandled_error", message: exception.message),
      )
    end
  end
end
