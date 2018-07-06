require 'rails_helper'

RSpec.describe Users::OmniauthCallbacksController do
  let(:user) { Fabricate(:user) }

  before do
    OmniAuth.config.test_mode = true
  end

  after do
    Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:google_oauth2] = nil
    OmniAuth.config.test_mode = false
  end

  describe ".find_authenticator" do
    it "fails if a provider is disabled" do
      SiteSetting.enable_twitter_logins = false

      expect do
        Users::OmniauthCallbacksController.find_authenticator("twitter")
      end.to raise_error(Discourse::InvalidAccess)
    end

    it "fails for unknown" do
      expect do
        Users::OmniauthCallbacksController.find_authenticator("twitter1")
      end.to raise_error(Discourse::InvalidAccess)
    end

    it "finds an authenticator when enabled" do
      SiteSetting.enable_twitter_logins = true

      expect(Users::OmniauthCallbacksController.find_authenticator("twitter"))
        .not_to eq(nil)
    end

    context "with a plugin-contributed auth provider" do

      let :provider do
        provider = Plugin::AuthProvider.new
        provider.authenticator = Auth::OpenIdAuthenticator.new('ubuntu', 'https://login.ubuntu.com', trusted: true)
        provider.enabled_setting = "ubuntu_login_enabled"
        provider
      end

      before do
        Discourse.stubs(:auth_providers).returns [provider]
      end

      it "finds an authenticator when enabled" do
        SiteSetting.stubs(:ubuntu_login_enabled).returns(true)

        expect(Users::OmniauthCallbacksController.find_authenticator("ubuntu"))
          .to be(provider.authenticator)
      end

      it "fails if an authenticator is disabled" do
        SiteSetting.stubs(:ubuntu_login_enabled).returns(false)

        expect { Users::OmniauthCallbacksController.find_authenticator("ubuntu") }
          .to raise_error(Discourse::InvalidAccess)
      end

      it "succeeds if an authenticator does not have a site setting" do
        provider.enabled_setting = nil
        SiteSetting.stubs(:ubuntu_login_enabled).returns(false)

        expect(Users::OmniauthCallbacksController.find_authenticator("ubuntu"))
          .to be(provider.authenticator)
      end
    end
  end

  context 'Google Oauth2' do
    before do
      SiteSetting.enable_google_oauth2_logins = true
    end

    context "without an `omniauth.auth` env" do
      it "should return a 404" do
        get "/auth/eviltrout/callback"
        expect(response.code).to eq("404")
      end
    end

    describe 'when user has been verified' do
      before do
        OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
          provider: 'google_oauth2',
          uid: '123545',
          info: OmniAuth::AuthHash::InfoHash.new(
            email: user.email,
            name: 'Some name'
          ),
          extra: {
            raw_info: OmniAuth::AuthHash.new(
              email_verified: true,
              email: user.email,
              family_name: 'Huh',
              given_name: user.name,
              gender: 'male',
              name: "#{user.name} Huh",
            )
          },
        )

        Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:google_oauth2]
      end

      it 'should return the right response' do
        expect(user.email_confirmed?).to eq(false)

        events = DiscourseEvent.track_events do
          get "/auth/google_oauth2/callback.json"
        end

        expect(events.map { |event| event[:event_name] }).to include(:user_logged_in, :user_first_logged_in)

        expect(response.status).to eq(200)

        response_body = JSON.parse(response.body)

        expect(response_body["authenticated"]).to eq(true)
        expect(response_body["awaiting_activation"]).to eq(false)
        expect(response_body["awaiting_approval"]).to eq(false)
        expect(response_body["not_allowed_from_ip_address"]).to eq(false)
        expect(response_body["admin_not_allowed_from_ip_address"]).to eq(false)

        user.reload
        expect(user.email_confirmed?).to eq(true)
      end

      it "should confirm email even when the tokens are expired" do
        user.email_tokens.update_all(confirmed: false, expired: true)

        user.reload
        expect(user.email_confirmed?).to eq(false)

        events = DiscourseEvent.track_events do
          get "/auth/google_oauth2/callback.json"
        end

        expect(events.map { |event| event[:event_name] }).to include(:user_logged_in, :user_first_logged_in)

        expect(response.status).to eq(200)

        user.reload
        expect(user.email_confirmed?).to eq(true)
      end

      it "should activate/unstage staged user" do
        user.update!(staged: true, registration_ip_address: nil)

        user.reload
        expect(user.staged).to eq(true)
        expect(user.registration_ip_address).to eq(nil)

        events = DiscourseEvent.track_events do
          get "/auth/google_oauth2/callback.json"
        end

        expect(events.map { |event| event[:event_name] }).to include(:user_logged_in, :user_first_logged_in)

        expect(response.status).to eq(200)

        user.reload
        expect(user.staged).to eq(false)
        expect(user.registration_ip_address).to be_present
      end

      context 'when user has second factor enabled' do
        before do
          user.create_totp(enabled: true)
        end

        it 'should return the right response' do
          get "/auth/google_oauth2/callback.json"

          expect(response.status).to eq(200)

          response_body = JSON.parse(response.body)

          expect(response_body["email"]).to eq(user.email)
          expect(response_body["omniauth_disallow_totp"]).to eq(true)

          user.update!(email: 'different@user.email')
          get "/auth/google_oauth2/callback.json"

          expect(response.status).to eq(200)
          expect(JSON.parse(response.body)["email"]).to eq(user.email)
        end
      end

      context 'when user has not verified his email' do
        before do
          GoogleUserInfo.create!(google_user_id: '12345', user: user)
          user.update!(active: false)

          OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
            provider: 'google_oauth2',
            uid: '12345',
            info: OmniAuth::AuthHash::InfoHash.new(
              email: 'someother_email@test.com',
              name: 'Some name'
            ),
            extra: {
              raw_info: OmniAuth::AuthHash.new(
                email_verified: true,
                email: 'someother_email@test.com',
                family_name: 'Huh',
                given_name: user.name,
                gender: 'male',
                name: "#{user.name} Huh",
              )
            },
          )

          Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:google_oauth2]
        end

        it 'should return the right response' do
          get "/auth/google_oauth2/callback.json"

          expect(response.status).to eq(200)

          response_body = JSON.parse(response.body)

          expect(user.reload.active).to eq(false)
          expect(response_body["authenticated"]).to eq(false)
          expect(response_body["awaiting_activation"]).to eq(true)
        end
      end
    end

    context 'after changing email' do
      require_dependency 'email_updater'

      def login(identity)
        OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
          provider: 'google_oauth2',
          uid: "123545#{identity[:username]}",
          info: OmniAuth::AuthHash::InfoHash.new(
            email: identity[:email],
            name: 'Some name'
          ),
          extra: {
            raw_info: OmniAuth::AuthHash.new(
              email_verified: true,
              email: identity[:email],
              family_name: 'Huh',
              given_name: identity[:name],
              gender: 'male',
              name: "#{identity[:name]} Huh",
            )
          },
        )

        Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:google_oauth2]

        get "/auth/google_oauth2/callback.json"
        expect(response.status).to eq(200)
        JSON.parse(response.body)
      end

      it 'activates the correct email' do
        old_email = 'old@email.com'
        old_identity = { name: 'Bob',
                         username: 'bob',
                         email: old_email }
        user = Fabricate(:user, email: old_email)
        new_email = 'new@email.com'
        new_identity = { name: 'Bob',
                         username: 'boguslaw',
                         email: new_email }

        updater = EmailUpdater.new(user.guardian, user)
        updater.change_to(new_email)

        user.reload
        expect(user.email).to eq(old_email)

        response = login(old_identity)
        expect(response['authenticated']).to eq(true)

        user.reload
        expect(user.email).to eq(old_email)

        response = login(new_identity)
        expect(response['authenticated']).to eq(nil)
        expect(response['email']).to eq(new_email)
      end
    end
  end
end
