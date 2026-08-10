# frozen_string_literal: true

RSpec.describe ProblemCheck::GoogleOauth2Config do
  subject(:check) { described_class.new }

  describe ".call" do
    before { SiteSetting.stubs(enable_google_oauth2_logins: enabled) }

    context "when Google OAuth is disabled" do
      let(:enabled) { false }

      it { expect(check).to be_chill_about_it }
    end

    context "when Google OAuth is enabled and configured" do
      let(:enabled) { true }

      before do
        SiteSetting.stubs(google_oauth2_client_id: "foo")
        SiteSetting.stubs(google_oauth2_client_secret: "bar")
      end

      it { expect(check).to be_chill_about_it }
    end

    context "when Google OAuth is enabled but missing client ID" do
      let(:enabled) { true }

      before do
        SiteSetting.stubs(google_oauth2_client_id: nil)
        SiteSetting.stubs(google_oauth2_client_secret: "bar")
      end

      it do
        expect(check).to have_a_problem.with_priority("low").with_message(
          '{{setting:enable_google_oauth2_logins}} is on, but {{setting:google_oauth2_client_id}} must still be set. <a href="https://meta.discourse.org/t/configuring-google-login-for-discourse/15858" target="_blank">See this guide to learn more</a>.',
        )
      end
    end

    context "when Google OAuth is enabled but missing client secret" do
      let(:enabled) { true }

      before do
        SiteSetting.stubs(google_oauth2_client_id: "foo")
        SiteSetting.stubs(google_oauth2_client_secret: nil)
      end

      it do
        expect(check).to have_a_problem.with_priority("low").with_message(
          '{{setting:enable_google_oauth2_logins}} is on, but {{setting:google_oauth2_client_secret}} must still be set. <a href="https://meta.discourse.org/t/configuring-google-login-for-discourse/15858" target="_blank">See this guide to learn more</a>.',
        )
      end
    end
  end
end
