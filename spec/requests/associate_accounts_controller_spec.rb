# frozen_string_literal: true

RSpec.describe Users::AssociateAccountsController do
  fab!(:user)
  fab!(:user2, :user)

  before { OmniAuth.config.test_mode = true }

  after do
    Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:google_oauth2] = nil
    OmniAuth.config.test_mode = false
  end

  context "when attempting reconnect" do
    before do
      enable_auth_provider(:google_oauth2)
      OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
        provider: "google_oauth2",
        uid: "12345",
        info: {
          email: "someemail@test.com",
        },
        extra: {
          raw_info: {
            email_verified: true,
          },
        },
      )

      Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:google_oauth2]
    end

    it "does not allow an existing shadow association to log in independently" do
      SiteSetting.allow_anonymous_mode = true
      master = Fabricate(:user, trust_level: TrustLevel[1])
      shadow = AnonymousShadowCreator.get(master)
      UserAssociatedAccount.create!(
        user: shadow,
        provider_name: "google_oauth2",
        provider_uid: "12345",
      )

      SiteSetting.delete_associated_accounts_on_password_reset = true
      email_token = Fabricate(:email_token, user: master, scope: EmailToken.scopes[:password_reset])
      put "/u/password-reset/#{email_token.token}.json", params: { password: "newpassword123" }
      expect(response.status).to eq(200)
      cookies.delete("_t")

      post "/auth/google_oauth2"
      get "/auth/google_oauth2/callback.json"
      expect(response.status).to eq(403)
      expect(UserAuthToken.where(user_id: shadow.id)).to be_empty
    end

    it "does not associate an external account with an anonymous shadow" do
      SiteSetting.allow_anonymous_mode = true
      master = Fabricate(:user, trust_level: TrustLevel[1])
      sign_in_and_switch_to_anonymous_mode(master)

      post "/auth/google_oauth2?reconnect=true"
      get "/auth/google_oauth2/callback.json"
      expect(response.status).to eq(302)
      uri = URI.parse(response.redirect_url)
      get "#{uri.path}.json"
      expect(response.status).to eq(403)

      post "#{uri.path}.json"

      expect(response.status).to eq(403)
      expect(UserAssociatedAccount.where(user_id: master.shadow_user.id)).to be_empty
    end

    it "associates the external account" do
      sign_in(user)

      # Reconnect flow:
      post "/auth/google_oauth2?reconnect=true"
      expect(response.status).to eq(302)
      expect(session[:auth_reconnect]).to eq(true)

      OmniAuth.config.mock_auth[:google_oauth2].uid = "123456"
      get "/auth/google_oauth2/callback.json"
      expect(response.status).to eq(302)

      expect(session[:current_user_id]).to eq(user.id) # Still logged in
      expect(UserAssociatedAccount.count).to eq(0) # Reconnect has not yet happened

      # Request associate info
      uri = URI.parse(response.redirect_url)
      get "#{uri.path}.json"
      data = response.parsed_body
      expect(data["provider_name"]).to eq("google_oauth2")
      expect(data["account_description"]).to eq("someemail@test.com")

      # Make the connection
      events = DiscourseEvent.track_events { post "#{uri.path}.json" }
      expect(events.any? { |e| e[:event_name] == :before_auth }).to eq(true)
      expect(
        events.any? do |e|
          e[:event_name] === :after_auth && Auth::GoogleOAuth2Authenticator === e[:params][0] &&
            !e[:params][1].failed?
        end,
      ).to eq(true)

      expect(response.status).to eq(200)
      expect(UserAssociatedAccount.count).to eq(1)

      # Token cannot be reused
      get "#{uri.path}.json"
      expect(response.status).to eq(404)
    end

    it "emails the user when an account is associated" do
      sign_in(user)

      post "/auth/google_oauth2?reconnect=true"
      OmniAuth.config.mock_auth[:google_oauth2].uid = "123456"
      get "/auth/google_oauth2/callback.json"

      uri = URI.parse(response.redirect_url)
      get "#{uri.path}.json"

      expect_enqueued_with(
        job: :critical_user_email,
        args: {
          type: "account_associated",
          user_id: user.id,
          provider_name: "Google",
        },
      ) { post "#{uri.path}.json" }

      expect(response.status).to eq(200)
    end

    it "restricts association to the current session" do
      sign_in(user)

      post "/auth/google_oauth2?reconnect=true"
      expect(response.status).to eq(302)
      expect(session[:auth_reconnect]).to eq(true)

      OmniAuth.config.mock_auth[:google_oauth2].uid = "123456"
      get "/auth/google_oauth2/callback.json"
      expect(response.status).to eq(302)

      expect(session[:current_user_id]).to eq(user.id) # Still logged in
      expect(UserAssociatedAccount.count).to eq(0) # Reconnect has not yet happened

      uri = URI.parse(response.redirect_url)
      get "#{uri.path}.json"
      data = response.parsed_body
      expect(data["provider_name"]).to eq("google_oauth2")
      expect(data["account_description"]).to eq("someemail@test.com")

      cookies.delete "_forum_session"

      get "#{uri.path}.json"
      expect(response.status).to eq(404)
    end

    it "returns the correct response for non-existent tokens" do
      sign_in(user)

      get "/associate/12345678901234567890123456789012.json"
      expect(response.status).to eq(404)

      get "/associate/shorttoken.json"
      expect(response.status).to eq(404)
    end

    it "requires login" do
      # XHR should 403
      get "/associate/#{SecureRandom.hex}.json"
      expect(response.status).to eq(403)
    end
  end
end
