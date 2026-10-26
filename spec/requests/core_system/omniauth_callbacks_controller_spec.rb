# frozen_string_literal: true

RSpec.describe Users::OmniauthCallbacksController do
  include OmniauthHelpers

  before do
    OmniAuth.config.test_mode = true
    SiteSetting.full_name_requirement = "optional_at_signup"
    SiteSetting.allow_new_registrations = true
    SiteSetting.must_approve_users = false
    SiteSetting.hide_email_address_taken = false
    @allow_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
  end

  after do
    %i[facebook github twitter discord linkedin_oidc google_oauth2].each do |provider|
      reset_omniauth_config(provider)
    end
    Rails.application.env_config["omniauth.origin"] = nil
    ActionController::Base.allow_forgery_protection = @allow_forgery_protection
  end

  def authenticate_provider(provider)
    get "/session/csrf.json"
    expect(response.status).to eq(200)

    post "/auth/#{provider}",
         params: {
           authenticity_token: response.parsed_body["csrf"],
           signup: true,
         }
    expect(response.status).to eq(302)
    expect(URI(response.location).path).to eq("/auth/#{provider}/callback")

    follow_redirect!
    expect(response.status).to eq(302)
    expect(URI(response.location).path).to eq("/")
  end

  def create_oauth_account(authentication:, name:)
    get "/session/hp.json"
    expect(response.status).to eq(200)
    honeypot = response.parsed_body

    get "/session/csrf.json"
    expect(response.status).to eq(200)

    post "/u.json",
         params: {
           email: authentication.fetch("email"),
           username: authentication.fetch("username"),
           name: name,
           password_confirmation: honeypot.fetch("value"),
           challenge: honeypot.fetch("challenge").reverse,
         },
         headers: {
           "X-CSRF-Token" => response.parsed_body.fetch("csrf"),
         }
    expect(response.status).to eq(200)
    expect(response.parsed_body["success"]).to eq(true)
  end

  describe "#complete" do
    {
      facebook: :mock_facebook_auth,
      github: :mock_github_auth,
      twitter: :mock_twitter_auth,
      discord: :mock_discord_auth,
      linkedin_oidc: :mock_linkedin_auth,
    }.each do |provider, mock_provider|
      it "logs in the existing #{provider} account without creating another user" do
        enable_auth_provider(provider)
        user =
          Fabricate(
            :user,
            email: OmniauthHelpers::EMAIL,
            username: OmniauthHelpers::USERNAME,
            password: "supersecurepassword",
          )
        if provider == :twitter
          UserAssociatedAccount.create!(
            provider_name: "twitter",
            user_id: user.id,
            provider_uid: OmniauthHelpers::UID,
          )
        end
        public_send(mock_provider)

        expect { authenticate_provider(provider) }.not_to change(User, :count)

        authentication = JSON.parse(cookies[:authentication_data])
        expect(authentication).to include(
          "authenticated" => true,
          "awaiting_activation" => false,
          "awaiting_approval" => false,
        )
        association = UserAssociatedAccount.find_by!(provider_name: provider, user_id: user.id)
        expect(association.provider_uid).to eq(OmniauthHelpers::UID)
        expect(user.user_auth_tokens.last.authenticated_with_oauth).to eq(true)

        get "/session/current.json"
        expect(response.status).to eq(200)
        expect(response.parsed_body.fetch("current_user")).to include(
          "id" => user.id,
          "username" => user.username,
        )
      end
    end

    {
      facebook: :mock_facebook_auth,
      github: :mock_github_auth,
      discord: :mock_discord_auth,
      linkedin_oidc: :mock_linkedin_auth,
    }.each do |provider, mock_provider|
      it "creates an active passwordless account from verified #{provider} signup details" do
        enable_auth_provider(provider)
        public_send(mock_provider)

        authenticate_provider(provider)

        authentication = JSON.parse(cookies[:authentication_data])
        expect(authentication).to include(
          "auth_provider" => provider.to_s,
          "email" => OmniauthHelpers::EMAIL,
          "email_valid" => true,
          "name" => OmniauthHelpers::FULL_NAME,
        )
        expect(authentication["username"]).to be_present

        expect do
          create_oauth_account(authentication: authentication, name: authentication.fetch("name"))
        end.to change(User, :count).by(1)
        expect(response.parsed_body["active"]).to eq(true)
        user = User.find(response.parsed_body.fetch("user_id"))
        expect(user).to have_attributes(
          email: OmniauthHelpers::EMAIL,
          username: authentication.fetch("username"),
          name: OmniauthHelpers::FULL_NAME,
          active: true,
        )
        expect(user.email_confirmed?).to eq(true)
        association = UserAssociatedAccount.find_by!(provider_name: provider, user_id: user.id)
        expect(association.provider_uid).to eq(OmniauthHelpers::UID)
        expect(user.user_auth_tokens.last.authenticated_with_oauth).to eq(true)

        get "/session/current.json"
        expect(response.status).to eq(200)
        expect(response.parsed_body.fetch("current_user")).to include(
          "id" => user.id,
          "username" => user.username,
        )
      end
    end

    it "requires email activation for an unverified GitHub signup" do
      enable_auth_provider(:github)
      mock_github_auth(verified: false)
      Jobs.run_immediately!

      authenticate_provider(:github)

      authentication = JSON.parse(cookies[:authentication_data])
      expect(authentication).to include(
        "auth_provider" => "github",
        "email" => OmniauthHelpers::EMAIL,
        "email_valid" => false,
        "username" => OmniauthHelpers::USERNAME,
        "name" => OmniauthHelpers::FULL_NAME,
      )

      expect do
        create_oauth_account(authentication: authentication, name: authentication.fetch("name"))
      end.to change(User, :count).by(1)
      expect(response.parsed_body).to include(
        "active" => false,
        "message" => I18n.t("login.activate_email", email: OmniauthHelpers::EMAIL),
      )
      user = User.find(response.parsed_body.fetch("user_id"))
      expect(user.email_confirmed?).to eq(false)
      expect(user.email).to eq(OmniauthHelpers::EMAIL)
      association = UserAssociatedAccount.find_by!(provider_name: "github", user_id: user.id)
      expect(association.provider_uid).to eq(OmniauthHelpers::UID)
      expect(ActionMailer::Base.deliveries.map(&:to)).to include([OmniauthHelpers::EMAIL])

      get "/session/current.json"
      expect(response.status).to eq(404)
    end

    { "" => "Test User", "Some Name" => "Some Name" }.each do |provider_name, submitted_name|
      it "accepts the required signup name #{submitted_name.inspect} with GitHub name #{provider_name.inspect}" do
        enable_auth_provider(:github)
        SiteSetting.full_name_requirement = "required_at_signup"
        SiteSetting.auth_overrides_name = true
        mock_github_auth(name: provider_name)

        authenticate_provider(:github)

        authentication = JSON.parse(cookies[:authentication_data])
        expect(authentication).to include(
          "auth_provider" => "github",
          "email" => OmniauthHelpers::EMAIL,
          "email_valid" => true,
          "username" => OmniauthHelpers::USERNAME,
          "name" => provider_name.presence,
        )
        get "/signup"
        expect(response.status).to eq(200)

        expect do
          create_oauth_account(authentication: authentication, name: submitted_name)
        end.to change(User, :count).by(1)
        expect(response.parsed_body["active"]).to eq(true)
        user = User.find(response.parsed_body.fetch("user_id"))
        expect(user.name).to eq(submitted_name)
        expect(user.email_confirmed?).to eq(true)
        association = UserAssociatedAccount.find_by!(provider_name: "github", user_id: user.id)
        expect(association.provider_uid).to eq(OmniauthHelpers::UID)

        get "/session/current.json"
        expect(response.status).to eq(200)
        expect(response.parsed_body.fetch("current_user")).to include(
          "id" => user.id,
          "username" => user.username,
        )
      end
    end
  end

  describe "#failure" do
    it "renders the provider request error without creating a session" do
      enable_auth_provider(:google_oauth2)

      get "/auth/failure", params: { message: "request_error" }

      expect(response.status).to eq(200)
      expect(Nokogiri.HTML5(response.body).at_css(".alert-error").text.strip).to eq(
        I18n.t("login.omniauth_error.request_error"),
      )

      get "/session/current.json"
      expect(response.status).to eq(404)
    end
  end
end
