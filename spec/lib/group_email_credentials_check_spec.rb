# frozen_string_literal: true

require 'rails_helper'
require 'net/smtp'
require 'net/imap'

describe GroupEmailCredentialsCheck do
  fab!(:group1) { Fabricate(:group) }
  fab!(:group2) { Fabricate(:smtp_group) }
  fab!(:group3) { Fabricate(:imap_group) }

  describe "#run" do
    it "does nothing if SMTP is disabled for the site" do
      expect_no_validate_any
      SiteSetting.enable_smtp = false
      expect(described_class.run).to eq([])
    end

    context "with smtp and imap enabled for the site" do
      before do
        SiteSetting.enable_smtp = true
        SiteSetting.enable_imap = true
      end

      it "does nothing if no groups have smtp enabled" do
        expect_no_validate_any
        group2.update!(smtp_enabled: false)
        group3.update!(smtp_enabled: false, imap_enabled: false)
        expect(described_class.run).to eq([])
      end

      it "returns an error message and the group ID if the group's SMTP settings error" do
        EmailSettingsValidator.expects(:validate_smtp).raises(
          Net::SMTPAuthenticationError.new("bad credentials")
        ).then.returns(true).at_least_once
        EmailSettingsValidator.stubs(:validate_imap).returns(true)

        expect(described_class.run).to eq([
          {
            group_full_name: group2.full_name,
            group_name: group2.name,
            group_id: group2.id,
            message: I18n.t("email_settings.smtp_authentication_error")
          }
        ])
      end

      it "returns an error message and the group ID if the group's IMAP settings error" do
        EmailSettingsValidator.stubs(:validate_smtp).returns(true)
        EmailSettingsValidator.expects(:validate_imap).raises(
          Net::IMAP::NoResponseError.new(stub(data: stub(text: "Invalid credentials")))
        ).once

        expect(described_class.run).to eq([
          {
            group_full_name: group3.full_name,
            group_name: group3.name,
            group_id: group3.id,
            message: I18n.t("email_settings.imap_authentication_error")
          }
        ])
      end

      it "returns no imap errors if imap is disabled for the site" do
        SiteSetting.enable_imap = false
        EmailSettingsValidator.stubs(:validate_smtp).returns(true)
        EmailSettingsValidator.expects(:validate_imap).never

        expect(described_class.run).to eq([])
      end
    end
  end

  def expect_no_validate_imap
    EmailSettingsValidator.expects(:validate_imap).never
  end

  def expect_no_validate_smtp
    EmailSettingsValidator.expects(:validate_smtp).never
  end

  def expect_no_validate_any
    expect_no_validate_smtp
    expect_no_validate_imap
  end
end
