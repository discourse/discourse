# frozen_string_literal: true

RSpec.describe ProblemCheck::MissingMailgunApiKey do
  subject(:check) { described_class.new }

  describe ".call" do
    before do
      SiteSetting.stubs(reply_by_email_enabled: replies_enabled)
      ActionMailer::Base.stubs(smtp_settings: { address: mailgun_address })
      SiteSetting.stubs(mailgun_api_key: api_key)
    end

    context "when replies are disabled" do
      let(:replies_enabled) { false }
      let(:mailgun_address) { anything }
      let(:api_key) { anything }

      it { expect(check).to be_chill_about_it }
    end

    context "when not using Mailgun for replies" do
      let(:replies_enabled) { false }
      let(:mailgun_address) { nil }
      let(:api_key) { anything }

      it { expect(check).to be_chill_about_it }
    end

    context "when using Mailgun without an API key" do
      let(:replies_enabled) { true }
      let(:mailgun_address) { "smtp.mailgun.org" }
      let(:api_key) { nil }

      it do
        expect(check).to have_a_problem.with_priority("low").with_message(
          "The server is configured to send emails via Mailgun but you haven't provided an API key used to verify the webhook messages.",
        )
      end
    end
  end
end
