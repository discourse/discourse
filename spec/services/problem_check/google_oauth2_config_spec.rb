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
          'The server is configured to allow signup and login with Google OAuth2 (enable_google_oauth2_logins), but the client id and client secret values are not set. Go to <a href="/admin/site_settings">the Site Settings</a> and update the settings. <a href="https://meta.discourse.org/t/configuring-google-login-for-discourse/15858" target="_blank">See this guide to learn more</a>.',
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
          'The server is configured to allow signup and login with Google OAuth2 (enable_google_oauth2_logins), but the client id and client secret values are not set. Go to <a href="/admin/site_settings">the Site Settings</a> and update the settings. <a href="https://meta.discourse.org/t/configuring-google-login-for-discourse/15858" target="_blank">See this guide to learn more</a>.',
        )
      end
    end
  end
end
