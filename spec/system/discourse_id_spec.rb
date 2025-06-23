# frozen_string_literal: true

describe "discourse login client auth" do
  include OmniauthHelpers

  before do
    OmniAuth.config.test_mode = true
    SiteSetting.enable_discourse_id = true
    SiteSetting.discourse_id_client_id = "asdasd"
    SiteSetting.discourse_id_client_secret = "wadayathink"

    OmniAuth.config.mock_auth[:discourse_id] = OmniAuth::AuthHash.new(
      provider: "discourse_id",
      uid: OmniauthHelpers::UID,
      info:
        OmniAuth::AuthHash::InfoHash.new(
          email: OmniauthHelpers::EMAIL,
          username: OmniauthHelpers::USERNAME,
        ),
    )

    Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:github]
  end

  after { reset_omniauth_config(:discourse_id) }

  let(:signup_form) { PageObjects::Pages::Signup.new }

  context "when user does not exist" do
    context "when auth_skip_create_confirm is false" do
      before { SiteSetting.auth_skip_create_confirm = false }

      it "skips the signup form and creates the account directly" do
        visit("/")
        signup_form.open.click_social_button("discourse_id")
        expect(page).to have_css(".login-welcome-header")
      end
    end

    context "when auth_skip_create_confirm is true" do
      before { SiteSetting.auth_skip_create_confirm = true }

      it "skips the signup form and creates the account directly" do
        visit("/")
        signup_form.open.click_social_button("discourse_id")
        expect(page).to have_css(".header-dropdown-toggle.current-user")
      end
    end
  end

  context "when user exists" do
    fab!(:user) do
      Fabricate(:user, email: OmniauthHelpers::EMAIL, username: OmniauthHelpers::USERNAME)
    end

    it "logs in user" do
      visit("/")
      signup_form.open.click_social_button("discourse_id")
      expect(page).to have_css(".header-dropdown-toggle.current-user")
    end
  end
end
