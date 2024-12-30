# frozen_string_literal: true

shared_context "with omniauth setup" do |signup_page_object, login_page_object|
  include OmniauthHelpers

  let(:login_form) { login_page_object }
  let(:signup_form) { signup_page_object }

  before { OmniAuth.config.test_mode = true }
end

shared_examples "social authentication scenarios" do |signup_page_object, login_page_object|
  include_context "with omniauth setup", signup_page_object, login_page_object

  context "when user does not exist" do
    context "with Facebook" do
      before { SiteSetting.enable_facebook_logins = true }
      after { reset_omniauth_config(:facebook) }

      it "fills the signup form" do
        mock_facebook_auth
        visit("/")

        signup_form.open.click_social_button("facebook")
        expect(signup_form).to be_open
        expect(signup_form).to have_no_password_input
        expect(signup_form).to have_valid_username
        expect(signup_form).to have_valid_email
        signup_form.click_create_account
        expect(page).to have_css(".header-dropdown-toggle.current-user")
      end
    end

    context "with Google" do
      before { SiteSetting.enable_google_oauth2_logins = true }
      after { reset_omniauth_config(:google_oauth2) }

      it "fills the signup form" do
        mock_google_auth
        visit("/")

        signup_form.open.click_social_button("google_oauth2")
        expect(signup_form).to be_open
        expect(signup_form).to have_no_password_input
        expect(signup_form).to have_valid_username
        expect(signup_form).to have_valid_email
        signup_form.click_create_account
        expect(page).to have_css(".header-dropdown-toggle.current-user")
      end

      context "when the email is not verified" do
        it "needs to verify email" do
          mock_google_auth(verified: false)
          visit("/")

          signup_form.open.click_social_button("google_oauth2")
          expect(signup_form).to be_open
          expect(signup_form).to have_no_password_input
          expect(signup_form).to have_valid_username
          expect(signup_form).to have_valid_email
          signup_form.click_create_account
          expect(page).to have_css(".account-created")
        end
      end
    end

    context "with Github" do
      before { SiteSetting.enable_github_logins = true }
      after { reset_omniauth_config(:github) }

      it "fills the signup form" do
        mock_github_auth
        visit("/")

        signup_form.open.click_social_button("github")
        expect(signup_form).to be_open
        expect(signup_form).to have_no_password_input
        expect(signup_form).to have_valid_username
        expect(signup_form).to have_valid_email
        signup_form.click_create_account
        expect(page).to have_css(".header-dropdown-toggle.current-user")
      end

      context "when the email is not verified" do
        it "needs to verify email" do
          mock_github_auth(verified: false)
          visit("/")

          signup_form.open.click_social_button("github")
          expect(signup_form).to be_open
          expect(signup_form).to have_no_password_input
          expect(signup_form).to have_valid_username
          expect(signup_form).to have_valid_email
          signup_form.click_create_account
          expect(page).to have_css(".account-created")
        end
      end
    end

    context "with Twitter" do
      before { SiteSetting.enable_twitter_logins = true }
      after { reset_omniauth_config(:twitter) }

      it "fills the signup form" do
        mock_twitter_auth
        visit("/")

        signup_form.open.click_social_button("twitter")
        expect(signup_form).to be_open
        expect(signup_form).to have_no_password_input
        signup_form.fill_email(OmniauthHelpers::EMAIL)
        expect(signup_form).to have_valid_username
        expect(signup_form).to have_valid_email
        signup_form.click_create_account
        expect(page).to have_css(".account-created")
      end

      context "when the email is not verified" do
        it "needs to verify email" do
          mock_twitter_auth(verified: false)
          visit("/")

          signup_form.open.click_social_button("twitter")
          expect(signup_form).to be_open
          expect(signup_form).to have_no_password_input
          signup_form.fill_email(OmniauthHelpers::EMAIL)
          expect(signup_form).to have_valid_username
          expect(signup_form).to have_valid_email
          signup_form.click_create_account
          expect(page).to have_css(".account-created")
        end
      end
    end

    context "with Discord" do
      before { SiteSetting.enable_discord_logins = true }
      after { reset_omniauth_config(:discord) }

      it "fills the signup form" do
        mock_discord_auth
        visit("/")

        signup_form.open.click_social_button("discord")
        expect(signup_form).to be_open
        expect(signup_form).to have_no_password_input
        expect(signup_form).to have_valid_username
        expect(signup_form).to have_valid_email
        signup_form.click_create_account
        expect(page).to have_css(".header-dropdown-toggle.current-user")
      end
    end

    context "with Linkedin" do
      before do
        SiteSetting.linkedin_oidc_client_id = "12345"
        SiteSetting.linkedin_oidc_client_secret = "abcde"
        SiteSetting.enable_linkedin_oidc_logins = true
      end
      after { reset_omniauth_config(:linkedin_oidc) }

      it "fills the signup form" do
        mock_linkedin_auth
        visit("/")

        signup_form.open.click_social_button("linkedin_oidc")
        expect(signup_form).to be_open
        expect(signup_form).to have_no_password_input
        expect(signup_form).to have_valid_username
        expect(signup_form).to have_valid_email
        signup_form.click_create_account
        expect(page).to have_css(".header-dropdown-toggle.current-user")
      end
    end

    # These tests use Google, but they should be the same for all providers

    context "when opening the external auth from /login" do
      before { SiteSetting.enable_google_oauth2_logins = true }
      after { reset_omniauth_config(:google_oauth2) }

      it "fills the signup form" do
        mock_google_auth
        visit("/")

        signup_form.open.click_social_button("google_oauth2")
        expect(signup_form).to be_open
        expect(signup_form).to have_no_password_input
        expect(signup_form).to have_valid_username
        expect(signup_form).to have_valid_email
        signup_form.click_create_account
        expect(page).to have_css(".header-dropdown-toggle.current-user")
      end
    end

    context "when overriding local fields" do
      before do
        SiteSetting.enable_google_oauth2_logins = true
        SiteSetting.auth_overrides_name = true
        SiteSetting.auth_overrides_username = true
      end
      after { reset_omniauth_config(:google_oauth2) }

      it "fills the signup form and disables the inputs" do
        mock_google_auth
        visit("/")

        signup_form.open.click_social_button("google_oauth2")
        expect(signup_form).to be_open
        expect(signup_form).to have_no_password_input
        expect(signup_form).to have_valid_username
        expect(signup_form).to have_valid_email
        expect(signup_form).to have_disabled_username
        expect(signup_form).to have_disabled_email
        expect(signup_form).to have_disabled_name
        signup_form.click_create_account
        expect(page).to have_css(".header-dropdown-toggle.current-user")
      end
    end

    context "when skipping the signup form" do
      before do
        SiteSetting.enable_google_oauth2_logins = true
        SiteSetting.auth_skip_create_confirm = true
      end
      after { reset_omniauth_config(:google_oauth2) }

      it "creates the account directly" do
        mock_google_auth
        visit("/")

        signup_form.open.click_social_button("google_oauth2")
        expect(page).to have_css(".header-dropdown-toggle.current-user")
      end
    end
  end

  context "when user exists" do
    fab!(:user) do
      Fabricate(
        :user,
        email: OmniauthHelpers::EMAIL,
        username: OmniauthHelpers::USERNAME,
        password: "supersecurepassword",
      )
    end

    context "with Facebook" do
      before { SiteSetting.enable_facebook_logins = true }
      after { reset_omniauth_config(:facebook) }

      it "logs in user" do
        mock_facebook_auth
        visit("/")

        signup_form.open.click_social_button("facebook")
        expect(page).to have_css(".header-dropdown-toggle.current-user")
      end
    end

    context "with Google" do
      before { SiteSetting.enable_google_oauth2_logins = true }
      after { reset_omniauth_config(:google_oauth2) }

      it "logs in user" do
        mock_google_auth
        visit("/")

        signup_form.open.click_social_button("google_oauth2")
        expect(page).to have_css(".header-dropdown-toggle.current-user")
      end
    end

    context "with Github" do
      before { SiteSetting.enable_github_logins = true }
      after { reset_omniauth_config(:github) }

      it "logs in user" do
        mock_github_auth
        visit("/")

        signup_form.open.click_social_button("github")
        expect(page).to have_css(".header-dropdown-toggle.current-user")
      end
    end

    context "with Twitter" do
      before { SiteSetting.enable_twitter_logins = true }
      after { reset_omniauth_config(:twitter) }

      it "logs in user" do
        UserAssociatedAccount.create!(
          provider_name: "twitter",
          user_id: user.id,
          provider_uid: OmniauthHelpers::UID,
        )

        mock_twitter_auth
        visit("/")

        signup_form.open.click_social_button("twitter")
        expect(page).to have_css(".header-dropdown-toggle.current-user")
      end
    end

    context "with Discord" do
      before { SiteSetting.enable_discord_logins = true }
      after { reset_omniauth_config(:discord) }

      it "logs in user" do
        mock_discord_auth
        visit("/")

        signup_form.open.click_social_button("discord")
        expect(page).to have_css(".header-dropdown-toggle.current-user")
      end
    end

    context "with Linkedin" do
      before do
        SiteSetting.linkedin_oidc_client_id = "12345"
        SiteSetting.linkedin_oidc_client_secret = "abcde"
        SiteSetting.enable_linkedin_oidc_logins = true
      end
      after { reset_omniauth_config(:linkedin_oidc) }

      it "logs in user" do
        mock_linkedin_auth
        visit("/")

        signup_form.open.click_social_button("linkedin_oidc")
        expect(page).to have_css(".header-dropdown-toggle.current-user")
      end
    end
  end
end

describe "Social authentication", type: :system do
  before { SiteSetting.full_name_requirement = "optional_at_signup" }

  context "when desktop" do
    include_examples "social authentication scenarios",
                     PageObjects::Modals::Signup.new,
                     PageObjects::Modals::Login.new
  end

  context "when mobile", mobile: true do
    include_examples "social authentication scenarios",
                     PageObjects::Modals::Signup.new,
                     PageObjects::Modals::Login.new
  end

  context "when fullpage desktop" do
    before { SiteSetting.full_page_login = true }
    include_examples "social authentication scenarios",
                     PageObjects::Pages::Signup.new,
                     PageObjects::Pages::Login.new
  end

  context "when fullpage mobile", mobile: true do
    before { SiteSetting.full_page_login = true }
    include_examples "social authentication scenarios",
                     PageObjects::Pages::Signup.new,
                     PageObjects::Pages::Login.new
  end
end
