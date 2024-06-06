# frozen_string_literal: true

require "rotp"

shared_examples "forgot password scenarios" do
  let(:login_modal) { PageObjects::Modals::Login.new }
  let(:user_preferences_security_page) { PageObjects::Pages::UserPreferencesSecurity.new }
  fab!(:user) { Fabricate(:user, username: "john", password: "supersecurepassword") }
  fab!(:password_reset_token) do
    Fabricate(
      :email_token,
      user:,
      scope: EmailToken.scopes[:password_reset],
      email: user.email,
    ).token
  end
  let(:user_menu) { PageObjects::Components::UserMenu.new }
  let(:user_reset_password_page) { PageObjects::Pages::UserResetPassword.new }

  def visit_reset_password_link
    visit("/u/password-reset/#{password_reset_token}")
  end

  def create_user_security_key(user)
    # testing the 2FA flow requires a user that was created > 5 minutes ago
    user.update!(created_at: 6.minutes.ago)

    sign_in(user)

    user_preferences_security_page.visit(user)
    user_preferences_security_page.visit_second_factor("supersecurepassword")

    find(".security-key .new-security-key").click
    expect(user_preferences_security_page).to have_css("input#security-key-name")

    find(".d-modal__body input#security-key-name").fill_in(with: "First Key")
    find(".add-security-key").click

    expect(user_preferences_security_page).to have_css(".security-key .second-factor-item")

    user_menu.sign_out
  end

  context "when user does not have any multi-factor authentication configured" do
    it "should allow a user to reset their password" do
      visit_reset_password_link

      user_reset_password_page.fill_in_new_password("newsuperpassword").submit_new_password

      expect(user_reset_password_page).to have_logged_in_user
    end
  end

  context "when user has multi-factor authentication configured" do
    context "when user only has TOTP configured" do
      fab!(:user_second_factor_totp) { Fabricate(:user_second_factor_totp, user:) }

      it "should allow a user to reset password with TOTP" do
        visit_reset_password_link

        expect(user_reset_password_page).to have_no_toggle_button_to_second_factor_form

        user_reset_password_page
          .fill_in_totp(ROTP::TOTP.new(user_second_factor_totp.data).now)
          .submit_totp
          .fill_in_new_password("newsuperpassword")
          .submit_new_password

        expect(user_reset_password_page).to have_logged_in_user
      end
    end

    context "when user only has security key configured" do
      before do
        @authenticator =
          page.driver.browser.add_virtual_authenticator(
            Selenium::WebDriver::VirtualAuthenticatorOptions.new,
          )

        create_user_security_key(user)
      end

      after { @authenticator.remove! }

      it "should allow a user to reset password with a security key" do
        visit_reset_password_link

        expect(user_reset_password_page).to have_no_toggle_button_to_second_factor_form

        user_reset_password_page.submit_security_key

        user_reset_password_page.fill_in_new_password("newsuperpassword").submit_new_password

        expect(user_reset_password_page).to have_logged_in_user
      end
    end

    context "when user has TOTP and backup codes configured" do
      fab!(:user_second_factor_backup) { Fabricate(:user_second_factor_backup, user:) }
      fab!(:user_second_factor_totp) { Fabricate(:user_second_factor_totp, user:) }

      it "should allow a user to reset password with backup code" do
        visit_reset_password_link

        user_reset_password_page
          .use_backup_codes
          .fill_in_backup_code("iAmValidBackupCode")
          .submit_backup_code
          .fill_in_new_password("newsuperpassword")
          .submit_new_password

        expect(user_reset_password_page).to have_logged_in_user
      end
    end

    context "when user has security key and backup codes configured" do
      fab!(:user_second_factor_backup) { Fabricate(:user_second_factor_backup, user:) }

      before do
        @authenticator =
          page.driver.browser.add_virtual_authenticator(
            Selenium::WebDriver::VirtualAuthenticatorOptions.new,
          )

        create_user_security_key(user)
      end

      after { @authenticator.remove! }

      it "should allow a user to reset password with backup code instead of security key" do
        visit_reset_password_link

        user_reset_password_page.try_another_way

        expect(user_reset_password_page).to have_no_toggle_button_in_second_factor_form

        user_reset_password_page
          .fill_in_backup_code("iAmValidBackupCode")
          .submit_backup_code
          .fill_in_new_password("newsuperpassword")
          .submit_new_password

        expect(user_reset_password_page).to have_logged_in_user
      end
    end

    context "when user has TOTP, security key and backup codes configured" do
      fab!(:user_second_factor_totp) { Fabricate(:user_second_factor_totp, user:) }
      fab!(:user_second_factor_backup) { Fabricate(:user_second_factor_backup, user:) }

      before do
        @authenticator =
          page.driver.browser.add_virtual_authenticator(
            Selenium::WebDriver::VirtualAuthenticatorOptions.new,
          )

        create_user_security_key(user)
      end

      after { @authenticator.remove! }

      it "should allow a user to toggle from security key to TOTP and between TOTP and backup codes" do
        visit_reset_password_link

        user_reset_password_page.try_another_way

        expect(user_reset_password_page).to have_totp_description

        user_reset_password_page.use_backup_codes

        expect(user_reset_password_page).to have_backup_codes_description

        user_reset_password_page.use_totp

        expect(user_reset_password_page).to have_totp_description
      end
    end

    context "when user has TOTP and security key configured but no backup codes" do
      fab!(:user_second_factor_totp) { Fabricate(:user_second_factor_totp, user:) }

      before do
        @authenticator =
          page.driver.browser.add_virtual_authenticator(
            Selenium::WebDriver::VirtualAuthenticatorOptions.new,
          )

        create_user_security_key(user)
      end

      after { @authenticator.remove! }

      it "should allow a user to reset password with TOTP instead of security key" do
        visit_reset_password_link

        user_reset_password_page.try_another_way

        expect(user_reset_password_page).to have_no_toggle_button_in_second_factor_form

        user_reset_password_page
          .fill_in_totp(ROTP::TOTP.new(user_second_factor_totp.data).now)
          .submit_totp
          .fill_in_new_password("newsuperpassword")
          .submit_new_password

        expect(user_reset_password_page).to have_logged_in_user
      end
    end
  end
end

describe "User resetting password", type: :system do
  context "when desktop" do
    include_examples "forgot password scenarios"
  end

  context "when mobile", mobile: true do
    include_examples "forgot password scenarios"
  end
end
