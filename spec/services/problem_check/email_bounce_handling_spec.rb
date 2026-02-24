# frozen_string_literal: true

RSpec.describe ProblemCheck::EmailBounceHandling do
  subject(:check) { described_class.new }

  before do
    SiteSetting.stubs(reply_by_email_enabled: reply_by_email_enabled)
    Email::Sender.stubs(:bounceable_reply_address?).returns(bounceable_reply_address)
    ActionMailer::Base.stubs(smtp_settings: { address: smtp_address })
  end

  context "when reply by email is enabled with VERP" do
    let(:reply_by_email_enabled) { true }
    let(:bounceable_reply_address) { true }
    let(:smtp_address) { "smtp.mailgun.org" }

    it { expect(check).to be_chill_about_it }
  end

  context "when reply by email is enabled without VERP" do
    let(:reply_by_email_enabled) { true }
    let(:bounceable_reply_address) { false }
    let(:smtp_address) { "smtp.mailgun.org" }

    before { SiteSetting.stubs(mailgun_api_key: "") }

    it { expect(check).to have_a_problem }
  end

  context "when reply by email is disabled with VERP address configured" do
    let(:reply_by_email_enabled) { false }
    let(:bounceable_reply_address) { true }
    let(:smtp_address) { "smtp.mailgun.org" }

    before { SiteSetting.stubs(mailgun_api_key: "") }

    it { expect(check).to have_a_problem }
  end

  context "when using Mailgun without an API key" do
    let(:reply_by_email_enabled) { false }
    let(:bounceable_reply_address) { false }
    let(:smtp_address) { "smtp.mailgun.org" }

    before { SiteSetting.stubs(mailgun_api_key: "") }

    it do
      expect(check).to have_a_problem.with_priority("low").with_message(
        I18n.t(
          "dashboard.problem.email_bounce_handling.webhook_key_missing",
          provider: "Mailgun",
          setting: "mailgun_api_key",
          base_path: Discourse.base_path,
        ),
      )
    end
  end

  context "when using Mailgun with an API key" do
    let(:reply_by_email_enabled) { false }
    let(:bounceable_reply_address) { false }
    let(:smtp_address) { "smtp.mailgun.org" }

    before { SiteSetting.stubs(mailgun_api_key: "key-123") }

    it { expect(check).to be_chill_about_it }
  end

  context "when using SendGrid without a verification key" do
    let(:reply_by_email_enabled) { false }
    let(:bounceable_reply_address) { false }
    let(:smtp_address) { "smtp.sendgrid.net" }

    before { SiteSetting.stubs(sendgrid_verification_key: "") }

    it do
      expect(check).to have_a_problem.with_priority("low").with_message(
        I18n.t(
          "dashboard.problem.email_bounce_handling.webhook_key_missing",
          provider: "SendGrid",
          setting: "sendgrid_verification_key",
          base_path: Discourse.base_path,
        ),
      )
    end
  end

  context "when using SendGrid with a verification key" do
    let(:reply_by_email_enabled) { false }
    let(:bounceable_reply_address) { false }
    let(:smtp_address) { "smtp.sendgrid.net" }

    before { SiteSetting.stubs(sendgrid_verification_key: "key-123") }

    it { expect(check).to be_chill_about_it }
  end

  context "when using Mailjet without a webhook token" do
    let(:reply_by_email_enabled) { false }
    let(:bounceable_reply_address) { false }
    let(:smtp_address) { "in-v3.mailjet.com" }

    before { SiteSetting.stubs(mailjet_webhook_token: "") }

    it { expect(check).to have_a_problem.with_priority("low") }
  end

  context "when using Mailpace without a verification key" do
    let(:reply_by_email_enabled) { false }
    let(:bounceable_reply_address) { false }
    let(:smtp_address) { "smtp.mailpace.com" }

    before { SiteSetting.stubs(mailpace_verification_key: "") }

    it { expect(check).to have_a_problem.with_priority("low") }
  end

  context "when using Mailpace with a verification key" do
    let(:reply_by_email_enabled) { false }
    let(:bounceable_reply_address) { false }
    let(:smtp_address) { "smtp.mailpace.com" }

    before { SiteSetting.stubs(mailpace_verification_key: "key-123") }

    it { expect(check).to be_chill_about_it }
  end

  context "when using AWS SES" do
    let(:reply_by_email_enabled) { false }
    let(:bounceable_reply_address) { false }
    let(:smtp_address) { "email-smtp.us-east-1.amazonaws.com" }

    it { expect(check).to be_chill_about_it }
  end

  context "when using an unknown provider" do
    let(:reply_by_email_enabled) { false }
    let(:bounceable_reply_address) { false }
    let(:smtp_address) { "smtp.unknown-provider.com" }

    it do
      expect(check).to have_a_problem.with_priority("low").with_message(
        I18n.t(
          "dashboard.problem.email_bounce_handling.no_bounce_handling",
          base_path: Discourse.base_path,
        ),
      )
    end
  end
end
