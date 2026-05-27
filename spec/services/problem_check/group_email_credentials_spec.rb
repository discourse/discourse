# frozen_string_literal: true

require "net/smtp"

RSpec.describe ProblemCheck::GroupEmailCredentials do
  subject(:check) { described_class.new(target) }

  fab!(:group1) { Fabricate(:group, smtp_enabled: false) }
  fab!(:smtp_group) { Fabricate(:smtp_group, name: "smtp_group") }

  describe "#call" do
    context "when SMTP is disabled for the site" do
      before { SiteSetting.enable_smtp = false }

      context "with an SMTP-enabled group" do
        let(:target) { smtp_group.name }

        it "does not report a problem" do
          expect(check).to be_chill_about_it
        end
      end
    end

    context "when SMTP is enabled for the site" do
      before { SiteSetting.enable_smtp = true }

      context "when the group has no SMTP enabled" do
        let(:target) { group1.name }

        it "does not report a problem" do
          expect(check).to be_chill_about_it
        end
      end

      context "when SMTP error check fails" do
        let(:target) { smtp_group.name }

        it "registers a problem with the group's SMTP settings error" do
          EmailSettingsValidator
            .expects(:validate_smtp)
            .raises(Net::SMTPAuthenticationError.new("bad credentials"))
            .then
            .returns(true)
            .at_least_once

          expect(check).to have_a_problem.with_priority("high").with_message(
            I18n.t(
              "dashboard.problem.group_email_credentials",
              base_path: Discourse.base_path,
              group_name: smtp_group.name,
              group_full_name: smtp_group.full_name,
              error: I18n.t("email_settings.smtp_authentication_error", message: "bad credentials"),
            ),
          )
        end
      end
    end
  end
end
