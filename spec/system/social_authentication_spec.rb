# frozen_string_literal: true

shared_context "with omniauth setup" do
  include OmniauthHelpers

  let(:login_page) { PageObjects::Pages::Login.new }
  let(:signup_page) { PageObjects::Pages::Signup.new }

  before { OmniAuth.config.test_mode = true }
end

shared_examples "social authentication scenarios" do
  include_context "with omniauth setup"

  context "when user does not exist" do
    context "with Facebook" do
      before { SiteSetting.enable_facebook_logins = true }
      after { reset_omniauth_config(:facebook) }

      it "fills the signup form" do
        mock_facebook_auth
        visit("/")

        signup_page.open.click_social_button("facebook")
        expect(signup_page).to be_open
        expect(signup_page).to have_no_password_input
        expect(signup_page).to have_valid_username
        expect(signup_page).to have_valid_email
        expect(signup_page).to have_no_right_side_column

        signup_page.click_create_account
        expect(page).to have_css(".header-dropdown-toggle.current-user")
      end
    end

    context "with Google" do
      before { SiteSetting.enable_google_oauth2_logins = true }
      after { reset_omniauth_config(:google_oauth2) }

      it "fills the signup form" do
        mock_google_auth
        visit("/")

        signup_page.open.click_social_button("google_oauth2")
        expect(signup_page).to be_open
        expect(signup_page).to have_no_password_input
        expect(signup_page).to have_valid_username
        expect(signup_page).to have_valid_email
        expect(signup_page).to have_no_right_side_column

        signup_page.click_create_account
        expect(page).to have_css(".header-dropdown-toggle.current-user")
      end

      context "when the email is not verified" do
        it "needs to verify email" do
          mock_google_auth(verified: false)
          visit("/")

          signup_page.open.click_social_button("google_oauth2")
          expect(signup_page).to be_open
          expect(signup_page).to have_no_password_input
          expect(signup_page).to have_valid_username
          expect(signup_page).to have_valid_email
          expect(signup_page).to have_no_right_side_column

          signup_page.click_create_account
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

        signup_page.open.click_social_button("github")
        expect(signup_page).to be_open
        expect(signup_page).to have_no_password_input
        expect(signup_page).to have_valid_username
        expect(signup_page).to have_valid_email
        expect(signup_page).to have_no_right_side_column
        signup_page.click_create_account
        expect(page).to have_css(".header-dropdown-toggle.current-user")
      end

      context "when the email is not verified" do
        it "needs to verify email" do
          mock_github_auth(verified: false)
          visit("/")

          signup_page.open.click_social_button("github")
          expect(signup_page).to be_open
          expect(signup_page).to have_no_password_input
          expect(signup_page).to have_valid_username
          expect(signup_page).to have_valid_email
          expect(signup_page).to have_no_right_side_column
          signup_page.click_create_account
          expect(page).to have_css(".account-created")
        end
      end

      context "when Full Name is set to Required and auth overrides name" do
        before do
          SiteSetting.full_name_requirement = "required_at_signup"
          SiteSetting.auth_overrides_name = true
        end

        it "lets user input Name when no name is provided" do
          mock_github_auth(name: "")
          visit("/")

          signup_page.open.click_social_button("github")
          expect(signup_page).to be_open
          expect(signup_page).to have_no_password_input
          expect(signup_page).to have_valid_username
          expect(signup_page).to have_valid_email
          expect(signup_page).to have_editable_name_input

          signup_page.fill_input("#new-account-name", "Test User")

          expect(signup_page).to have_no_right_side_column
          signup_page.click_create_account
          expect(page).to have_css(".header-dropdown-toggle.current-user")
        end

        it "works with a provided name" do
          mock_github_auth(name: "Some Name")
          visit("/")

          signup_page.open.click_social_button("github")
          expect(signup_page).to be_open
          expect(signup_page).to have_no_password_input
          expect(signup_page).to have_valid_username
          expect(signup_page).to have_valid_email
          expect(signup_page).to have_disabled_name_input

          signup_page.click_create_account
          expect(page).to have_css(".header-dropdown-toggle.current-user")
        end
      end
    end

    context "with Twitter" do
      before { SiteSetting.enable_twitter_logins = true }
      after { reset_omniauth_config(:twitter) }

      it "fills the signup form" do
        mock_twitter_auth
        visit("/")

        signup_page.open.click_social_button("twitter")
        expect(signup_page).to be_open
        expect(signup_page).to have_no_password_input
        signup_page.fill_email(OmniauthHelpers::EMAIL)
        expect(signup_page).to have_valid_username
        expect(signup_page).to have_valid_email
        expect(signup_page).to have_no_right_side_column
        signup_page.click_create_account
        expect(page).to have_css(".account-created")
      end

      context "when the email is not verified" do
        it "needs to verify email" do
          mock_twitter_auth(verified: false)
          visit("/")

          signup_page.open.click_social_button("twitter")
          expect(signup_page).to be_open
          expect(signup_page).to have_no_password_input
          signup_page.fill_email(OmniauthHelpers::EMAIL)
          expect(signup_page).to have_valid_username
          expect(signup_page).to have_valid_email
          signup_page.click_create_account
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

        signup_page.open.click_social_button("discord")
        expect(signup_page).to be_open
        expect(signup_page).to have_no_password_input
        expect(signup_page).to have_valid_username
        expect(signup_page).to have_valid_email
        expect(signup_page).to have_no_right_side_column
        signup_page.click_create_account
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

        signup_page.open.click_social_button("linkedin_oidc")
        expect(signup_page).to be_open
        expect(signup_page).to have_no_password_input
        expect(signup_page).to have_valid_username
        expect(signup_page).to have_valid_email
        expect(signup_page).to have_no_right_side_column
        signup_page.click_create_account
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

        signup_page.open.click_social_button("google_oauth2")
        expect(signup_page).to be_open
        expect(signup_page).to have_no_password_input
        expect(signup_page).to have_valid_username
        expect(signup_page).to have_valid_email
        expect(signup_page).to have_no_right_side_column
        signup_page.click_create_account
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

        signup_page.open.click_social_button("google_oauth2")
        expect(signup_page).to be_open
        expect(signup_page).to have_no_password_input
        expect(signup_page).to have_valid_username
        expect(signup_page).to have_valid_email
        expect(signup_page).to have_disabled_username
        expect(signup_page).to have_disabled_email
        expect(signup_page).to have_disabled_name
        signup_page.click_create_account
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

        signup_page.open.click_social_button("google_oauth2")
        expect(page).to have_css(".header-dropdown-toggle.current-user")
      end
    end

    context "when there is only one external login method enabled" do
      before do
        SiteSetting.enable_google_oauth2_logins = true
        SiteSetting.enable_local_logins = false
      end
      after { reset_omniauth_config(:google_oauth2) }

      context "when login is required" do
        before { SiteSetting.login_required = true }

        it "automatically redirects when auth_immediately is enabled" do
          SiteSetting.auth_immediately = true
          mock_google_auth

          visit("/login")
          expect(signup_page).to be_open
          expect(signup_page).to have_no_password_input
          expect(signup_page).to have_valid_username
          expect(signup_page).to have_valid_email

          visit("/signup")
          expect(signup_page).to be_open
          expect(signup_page).to have_no_password_input
          expect(signup_page).to have_valid_username
          expect(signup_page).to have_valid_email

          visit("/")
          expect(signup_page).to be_open
          expect(signup_page).to have_no_password_input
          expect(signup_page).to have_valid_username
          expect(signup_page).to have_valid_email

          signup_page.click_create_account
          expect(page).to have_css(".header-dropdown-toggle.current-user")
        end

        it "shows the login-required page when auth_immediately is disabled" do
          SiteSetting.auth_immediately = false
          mock_google_auth

          visit("/login")
          expect(signup_page).to be_open

          visit("/")
          expect(page).to have_css(".login-welcome")
          expect(page).to have_css(".site-logo")

          find(".login-welcome .login-button").click
          expect(signup_page).to be_open

          visit("/")
          find(".login-welcome .sign-up-button").click
          expect(signup_page).to be_open
          expect(signup_page).to have_no_password_input
          expect(signup_page).to have_valid_username
          expect(signup_page).to have_valid_email
          signup_page.click_create_account
          expect(page).to have_css(".header-dropdown-toggle.current-user")
        end

        it "automatically redirects when going to /signup" do
          SiteSetting.auth_immediately = false
          mock_google_auth

          visit("/signup")
          expect(signup_page).to be_open
          expect(signup_page).to have_no_password_input
          expect(signup_page).to have_valid_username
          expect(signup_page).to have_valid_email
          signup_page.click_create_account
          expect(page).to have_css(".header-dropdown-toggle.current-user")
        end

        it "automatically redirects when skipping the signup form" do
          SiteSetting.auth_skip_create_confirm = true
          SiteSetting.auth_immediately = true
          mock_google_auth

          visit("/login")
          expect(page).to have_css(".header-dropdown-toggle.current-user")
        end
      end

      it "automatically redirects when using the login button or the routes" do
        SiteSetting.auth_immediately = false
        mock_google_auth

        visit("/")
        find(".header-buttons .login-button").click
        expect(signup_page).to be_open
        expect(signup_page).to have_no_password_input
        expect(signup_page).to have_valid_username
        expect(signup_page).to have_valid_email

        visit("/login")
        expect(signup_page).to be_open
        expect(signup_page).to have_no_password_input
        expect(signup_page).to have_valid_username
        expect(signup_page).to have_valid_email

        visit("/signup")
        expect(signup_page).to be_open
        expect(signup_page).to have_no_password_input
        expect(signup_page).to have_valid_username
        expect(signup_page).to have_valid_email

        signup_page.click_create_account
        expect(page).to have_css(".header-dropdown-toggle.current-user")
      end

      it "redirects the user back to the last page they visited" do
        mock_google_auth

        category = Fabricate(:category)

        visit(category.url)

        find(".header-buttons .login-button").click

        expect(signup_page).to be_open
        expect(signup_page).to have_no_password_input
        expect(signup_page).to have_valid_username
        expect(signup_page).to have_valid_email

        signup_page.click_create_account

        expect(page).to have_css(".header-dropdown-toggle.current-user")
        expect(page).to have_current_path(category.url)
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

        signup_page.open.click_social_button("facebook")
        expect(page).to have_css(".header-dropdown-toggle.current-user")
      end

      it "removes destination_url cookie if present after setting up redirect" do
        mock_facebook_auth
        visit("/")

        category = Fabricate(:category)

        signup_page.open

        # Manually set the destination_url, as if it were set by a plugin like discourse-login
        page.driver.with_playwright_page do |pw_page|
          pw_page.context.add_cookies(
            [{ url: pw_page.url, name: :destination_url, value: category.url }],
          )

          cookie_found =
            pw_page.context.cookies.any? { |cookie| cookie["name"] == "destination_url" }
          expect(cookie_found).not_to be_falsey
        end

        signup_page.click_social_button("facebook")
        expect(page).to have_current_path(category.url)

        # Ensure the destination_url cookie was removed after being used
        page.driver.with_playwright_page do |pw_page|
          cookie_found =
            pw_page.context.cookies.any? { |cookie| cookie["name"] == "destination_url" }
          expect(cookie_found).to be_falsey
        end
      end

      context "with a suspended user" do
        before do
          user.suspended_till = 2.years.from_now
          user.suspended_at = Time.now
          user.save!
        end

        it "shows suspended message" do
          mock_facebook_auth
          visit("/")

          signup_page.open.click_social_button("facebook")

          expect(page).to have_css(
            ".alert-error",
            text: I18n.t("login.suspended", date: I18n.l(user.suspended_till, format: :date_only)),
          )
        end
      end
    end

    context "with Google" do
      before { SiteSetting.enable_google_oauth2_logins = true }
      after { reset_omniauth_config(:google_oauth2) }

      it "logs in user" do
        mock_google_auth
        visit("/")

        signup_page.open.click_social_button("google_oauth2")
        expect(page).to have_css(".header-dropdown-toggle.current-user")
      end
    end

    context "with Github" do
      before { SiteSetting.enable_github_logins = true }
      after { reset_omniauth_config(:github) }

      it "logs in user" do
        mock_github_auth
        visit("/")

        signup_page.open.click_social_button("github")
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

        signup_page.open.click_social_button("twitter")
        expect(page).to have_css(".header-dropdown-toggle.current-user")
      end
    end

    context "with Discord" do
      before { SiteSetting.enable_discord_logins = true }
      after { reset_omniauth_config(:discord) }

      it "logs in user" do
        mock_discord_auth
        visit("/")

        signup_page.open.click_social_button("discord")
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

        signup_page.open.click_social_button("linkedin_oidc")
        expect(page).to have_css(".header-dropdown-toggle.current-user")
      end
    end
  end
end

describe "Social authentication", type: :system do
  before { SiteSetting.full_name_requirement = "optional_at_signup" }

  context "when desktop" do
    include_examples "social authentication scenarios"
  end

  context "when mobile", mobile: true do
    include_examples "social authentication scenarios"
  end
end
