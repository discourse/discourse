# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmailSettingsValidator do
  let(:username) { "kwest@gmail.com" }
  let(:password) { "mbdtf" }

  describe "#friendly_exception_message" do
    it "formats a Net::POPAuthenticationError" do
      exception = Net::POPAuthenticationError.new("invalid credentials")
      expect(subject.class.friendly_exception_message(exception)).to eq(
        I18n.t("email_settings.pop3_authentication_error")
      )
    end

    it "formats a Net::IMAP::NoResponseError for invalid credentials" do
      exception = Net::IMAP::NoResponseError.new(stub(data: stub(text: "Invalid credentials")))
      expect(subject.class.friendly_exception_message(exception)).to eq(
        I18n.t("email_settings.imap_authentication_error")
      )
    end

    it "formats a general Net::IMAP::NoResponseError" do
      exception = Net::IMAP::NoResponseError.new(stub(data: stub(text: "NO bad problem (Failure)")))
      expect(subject.class.friendly_exception_message(exception)).to eq(
        I18n.t("email_settings.imap_no_response_error", message: "NO bad problem")
      )
    end

    it "formats a Net::SMTPAuthenticationError" do
      exception = Net::SMTPAuthenticationError.new("invalid credentials")
      expect(subject.class.friendly_exception_message(exception)).to eq(
        I18n.t("email_settings.smtp_authentication_error")
      )
    end

    it "formats a Net::SMTPServerBusy" do
      exception = Net::SMTPServerBusy.new("call me maybe later")
      expect(subject.class.friendly_exception_message(exception)).to eq(
        I18n.t("email_settings.smtp_server_busy_error")
      )
    end

    it "formats a Net::SMTPSyntaxError, Net::SMTPFatalError, and Net::SMTPUnknownError" do
      exception = Net::SMTPSyntaxError.new("bad syntax")
      expect(subject.class.friendly_exception_message(exception)).to eq(
        I18n.t("email_settings.smtp_unhandled_error", message: exception.message)
      )
      exception = Net::SMTPFatalError.new("fatal")
      expect(subject.class.friendly_exception_message(exception)).to eq(
        I18n.t("email_settings.smtp_unhandled_error", message: exception.message)
      )
      exception = Net::SMTPUnknownError.new("unknown")
      expect(subject.class.friendly_exception_message(exception)).to eq(
        I18n.t("email_settings.smtp_unhandled_error", message: exception.message)
      )
    end

    it "formats a SocketError and Errno::ECONNREFUSED" do
      exception = SocketError.new("bad socket")
      expect(subject.class.friendly_exception_message(exception)).to eq(
        I18n.t("email_settings.connection_error")
      )
      exception = Errno::ECONNREFUSED.new("no thanks")
      expect(subject.class.friendly_exception_message(exception)).to eq(
        I18n.t("email_settings.connection_error")
      )
    end

    it "formats a Net::OpenTimeout and Net::ReadTimeout error" do
      exception = Net::OpenTimeout.new("timed out")
      expect(subject.class.friendly_exception_message(exception)).to eq(
        I18n.t("email_settings.timeout_error")
      )
      exception = Net::ReadTimeout.new("timed out")
      expect(subject.class.friendly_exception_message(exception)).to eq(
        I18n.t("email_settings.timeout_error")
      )
    end

    it "formats unhandled errors" do
      exception = StandardError.new("unknown")
      expect(subject.class.friendly_exception_message(exception)).to eq(
        I18n.t("email_settings.unhandled_error", message: exception.message)
      )
    end
  end

  describe "#validate_imap" do
    let(:host) { "imap.gmail.com" }
    let(:port) { 993 }

    let(:net_imap_stub) do
      obj = mock()
      obj.stubs(:login).returns(true)
      obj
    end

    before do
      Net::IMAP.stubs(:new).returns(net_imap_stub)
    end

    it "is valid if no error is raised" do
      net_imap_stub.stubs(:logout).returns(true)
      net_imap_stub.stubs(:disconnect).returns(true)
      expect { subject.class.validate_imap(host: host, port: port, username: username, password: password) }.not_to raise_error
    end

    it "is invalid if an error is raised" do
      net_imap_stub.stubs(:login).raises(Net::IMAP::NoResponseError, stub(data: stub(text: "no response")))
      expect { subject.class.validate_imap(host: host, port: port, username: username, password: password, debug: true) }.to raise_error(Net::IMAP::NoResponseError)
    end

    it "logs a warning if debug: true passed in and still raises the error" do
      net_imap_stub.stubs(:login).raises(Net::IMAP::NoResponseError, stub(data: stub(text: "no response")))
      Rails.logger.expects(:warn).with(regexp_matches(/\[EmailSettingsValidator\] Error encountered/)).at_least_once
      expect { subject.class.validate_imap(host: host, port: port, username: username, password: password, debug: true) }.to raise_error(Net::IMAP::NoResponseError)
    end
  end

  describe "#validate_pop3" do
    let(:host) { "pop.gmail.com" }
    let(:port) { 995 }

    let(:net_pop3_stub) do
      obj = mock()
      obj.stubs(:auth_only).returns(true)
      obj.stubs(:enable_ssl).returns(true)
      obj
    end

    before do
      Net::POP3.stubs(:new).returns(net_pop3_stub)
    end

    it "is valid if no error is raised" do
      expect { subject.class.validate_pop3(host: host, port: port, username: username, password: password) }.not_to raise_error
    end

    it "is invalid if an error is raised" do
      net_pop3_stub.stubs(:auth_only).raises(Net::POPAuthenticationError, "invalid credentials")
      expect { subject.class.validate_pop3(host: host, port: port, username: username, password: password, debug: true) }.to raise_error(Net::POPAuthenticationError)
    end

    it "logs a warning if debug: true passed in and still raises the error" do
      Rails.logger.expects(:warn).with(regexp_matches(/\[EmailSettingsValidator\] Error encountered/)).at_least_once
      net_pop3_stub.stubs(:auth_only).raises(Net::POPAuthenticationError, "invalid credentials")
      expect { subject.class.validate_pop3(host: host, port: port, username: username, password: password, debug: true) }.to raise_error(Net::POPAuthenticationError)
    end

    it "uses the correct ssl verify params if those settings are enabled" do
      SiteSetting.pop3_polling_ssl = true
      SiteSetting.pop3_polling_openssl_verify = true
      net_pop3_stub.expects(:enable_ssl).with(max_version: OpenSSL::SSL::TLS1_2_VERSION)
      expect { subject.class.validate_pop3(host: host, port: port, username: username, password: password) }.not_to raise_error
    end

    it "uses the correct ssl verify params if openssl_verify is not enabled" do
      SiteSetting.pop3_polling_ssl = true
      SiteSetting.pop3_polling_openssl_verify = false
      net_pop3_stub.expects(:enable_ssl).with(OpenSSL::SSL::VERIFY_NONE)
      expect { subject.class.validate_pop3(host: host, port: port, username: username, password: password) }.not_to raise_error
    end
  end

  describe "#validate_smtp" do
    let(:host) { "smtp.gmail.com" }
    let(:port) { 587 }
    let(:domain) { "gmail.com" }

    let(:net_smtp_stub) do
      obj = mock()
      obj.stubs(:start).returns(true)
      obj.stubs(:finish).returns(true)
      obj.stubs(:enable_tls).returns(true)
      obj.stubs(:enable_starttls_auto).returns(true)
      obj
    end

    before do
      Net::SMTP.stubs(:new).returns(net_smtp_stub)
    end

    it "is valid if no error is raised" do
      expect { subject.class.validate_smtp(host: host, port: port, username: username, password: password, domain: domain) }.not_to raise_error
    end

    it "is invalid if an error is raised" do
      net_smtp_stub.stubs(:start).raises(Net::SMTPAuthenticationError, "invalid credentials")
      expect { subject.class.validate_smtp(host: host, port: port, username: username, password: password, domain: domain) }.to raise_error(Net::SMTPAuthenticationError)
    end

    it "logs a warning if debug: true passed in and still raises the error" do
      Rails.logger.expects(:warn).with(regexp_matches(/\[EmailSettingsValidator\] Error encountered/)).at_least_once
      net_smtp_stub.stubs(:start).raises(Net::SMTPAuthenticationError, "invalid credentials")
      expect { subject.class.validate_smtp(host: host, port: port, username: username, password: password, debug: true, domain: domain) }.to raise_error(Net::SMTPAuthenticationError)
    end

    it "uses the correct ssl verify params for enable_tls if those settings are enabled" do
      net_smtp_stub.expects(:enable_tls)
      expect { subject.class.validate_smtp(host: host, port: port, username: username, password: password, domain: domain, openssl_verify_mode: "peer", enable_tls: true, enable_starttls_auto: false) }.not_to raise_error
    end

    it "uses the correct ssl verify params for enable_starttls_auto if those settings are enabled" do
      net_smtp_stub.expects(:enable_starttls_auto)
      expect { subject.class.validate_smtp(host: host, port: port, username: username, password: password, domain: domain, openssl_verify_mode: "peer", enable_tls: false, enable_starttls_auto: true) }.not_to raise_error
    end

    it "raises an ArgumentError if both enable_tls is true and enable_starttls_auto is true" do
      expect { subject.class.validate_smtp(host: host, port: port, username: username, password: password, domain: domain, enable_ssl: true, enable_starttls_auto: true) }.to raise_error(ArgumentError)
    end

    it "raises an ArgumentError if a bad authentication method is used" do
      expect { subject.class.validate_smtp(host: host, port: port, username: username, password: password, domain: domain, authentication: :rubber_stamp) }.to raise_error(ArgumentError)
    end
  end
end
