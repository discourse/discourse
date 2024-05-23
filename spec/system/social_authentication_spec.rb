# frozen_string_literal: true

shared_context "with omniauth setup" do
  include OmniauthHelpers

  let(:login_modal) { PageObjects::Modals::Login.new }
  let(:signup_modal) { PageObjects::Modals::Signup.new }

  before { OmniAuth.config.test_mode = true }
end

shared_examples "social authentication scenarios" do
  include_context "with omniauth setup"

  context "for Facebook" do
    before { SiteSetting.enable_facebook_logins = true }
    after { reset_omniauth_config(:facebook) }

    it "works" do
      mock_facebook_auth
      visit("/")

      login_modal.open
      login_modal.click_social_button("facebook")
      expect(signup_modal).to be_open
      expect(signup_modal).to have_no_password_input
      expect(signup_modal).to have_valid_username
      expect(signup_modal).to have_valid_email
      signup_modal.click_create_account
      expect(page).to have_css(".header-dropdown-toggle.current-user")
    end
  end

  context "for Google" do
    before { SiteSetting.enable_google_oauth2_logins = true }
    after { reset_omniauth_config(:google_oauth2) }

    it "works" do
      mock_google_auth
      visit("/")

      login_modal.open
      login_modal.click_social_button("google_oauth2")
      expect(signup_modal).to be_open
      expect(signup_modal).to have_no_password_input
      expect(signup_modal).to have_valid_username
      expect(signup_modal).to have_valid_email
      signup_modal.click_create_account
      expect(page).to have_css(".header-dropdown-toggle.current-user")
    end
  end

  context "for Github" do
    before { SiteSetting.enable_github_logins = true }
    after { reset_omniauth_config(:github) }

    it "works" do
      mock_github_auth
      visit("/")

      login_modal.open
      login_modal.click_social_button("github")
      expect(signup_modal).to be_open
      expect(signup_modal).to have_no_password_input
      expect(signup_modal).to have_valid_username
      expect(signup_modal).to have_valid_email
      signup_modal.click_create_account
      expect(page).to have_css(".header-dropdown-toggle.current-user")
    end
  end

  context "for Twitter" do
    before { SiteSetting.enable_twitter_logins = true }
    after { reset_omniauth_config(:twitter) }

    it "works" do
      mock_twitter_auth
      visit("/")

      login_modal.open
      login_modal.click_social_button("twitter")
      expect(signup_modal).to be_open
      expect(signup_modal).to have_no_password_input
      signup_modal.fill_email(OmniauthHelpers::EMAIL)
      expect(signup_modal).to have_valid_username
      expect(signup_modal).to have_valid_email
      signup_modal.click_create_account
      expect(page).to have_css(".account-created")
    end
  end

  context "for Discord" do
    before { SiteSetting.enable_discord_logins = true }
    after { reset_omniauth_config(:discord) }

    it "works" do
      mock_discord_auth
      visit("/")

      login_modal.open
      login_modal.click_social_button("discord")
      expect(signup_modal).to be_open
      expect(signup_modal).to have_no_password_input
      expect(signup_modal).to have_valid_username
      expect(signup_modal).to have_valid_email
      signup_modal.click_create_account
      expect(page).to have_css(".header-dropdown-toggle.current-user")
    end
  end

  context "for Linkedin" do
    before do
      SiteSetting.linkedin_oidc_client_id = "12345"
      SiteSetting.linkedin_oidc_client_secret = "abcde"
      SiteSetting.enable_linkedin_oidc_logins = true
    end
    after { reset_omniauth_config(:linkedin_oidc) }

    it "works" do
      mock_linkedin_auth
      visit("/")

      login_modal.open
      login_modal.click_social_button("linkedin_oidc")
      expect(signup_modal).to be_open
      expect(signup_modal).to have_no_password_input
      expect(signup_modal).to have_valid_username
      expect(signup_modal).to have_valid_email
      signup_modal.click_create_account
      expect(page).to have_css(".header-dropdown-toggle.current-user")
    end
  end
end

describe "Social authentication", type: :system do
  context "when desktop" do
    include_examples "social authentication scenarios"
  end

  context "when mobile", mobile: true do
    include_examples "social authentication scenarios"
  end
end
