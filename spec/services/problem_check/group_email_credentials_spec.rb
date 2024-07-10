# frozen_string_literal: true

require "net/smtp"
require "net/imap"

RSpec.describe ProblemCheck::GroupEmailCredentials do
  subject(:check) { described_class.new }

  fab!(:group1) { Fabricate(:group) }
  fab!(:group2) { Fabricate(:smtp_group) }
  fab!(:group3) { Fabricate(:imap_group) }

  describe "#call" do
    it "does nothing if SMTP is disabled for the site" do
      expect_no_validate_any
      SiteSetting.enable_smtp = false
      expect(check).to be_chill_about_it
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
        expect(check).to be_chill_about_it
      end

      it "returns a problem with the group's SMTP settings error" do
        EmailSettingsValidator
          .expects(:validate_smtp)
          .raises(Net::SMTPAuthenticationError.new("bad credentials"))
          .then
          .returns(true)
          .at_least_once
        EmailSettingsValidator.stubs(:validate_imap).returns(true)

        expect(described_class.new.call).to contain_exactly(
          have_attributes(
            identifier: "group_email_credentials",
            target: group2.id,
            priority: "high",
            message:
              "There was an issue with the email credentials for the group <a href=\"/g/#{group2.name}/manage/email\"></a>. No emails will be sent from the group inbox until this problem is addressed. There was an issue with the SMTP credentials provided, check the username and password and try again.",
          ),
        )
      end

      it "returns an error message and the group ID if the group's IMAP settings error" do
        EmailSettingsValidator.stubs(:validate_smtp).returns(true)
        EmailSettingsValidator
          .expects(:validate_imap)
          .raises(Net::IMAP::NoResponseError.new(stub(data: stub(text: "Invalid credentials"))))
          .once

        expect(described_class.new.call).to contain_exactly(
          have_attributes(
            identifier: "group_email_credentials",
            target: group3.id,
            priority: "high",
            message:
              "There was an issue with the email credentials for the group <a href=\"/g/#{group3.name}/manage/email\"></a>. No emails will be sent from the group inbox until this problem is addressed. There was an issue with the IMAP credentials provided, check the username and password and try again.",
          ),
        )
      end

      it "returns no imap errors if imap is disabled for the site" do
        SiteSetting.enable_imap = false
        EmailSettingsValidator.stubs(:validate_smtp).returns(true)
        EmailSettingsValidator.expects(:validate_imap).never

        expect(described_class.new.call).to eq([])
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
