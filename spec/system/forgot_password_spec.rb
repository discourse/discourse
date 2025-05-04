# frozen_string_literal: true

require "rotp"

shared_examples "forgot password scenarios" do
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
      it "should allow a user to reset password with a security key" do
        with_security_key(user) do
          visit_reset_password_link

          expect(user_reset_password_page).to have_no_toggle_button_to_second_factor_form

          user_reset_password_page.submit_security_key

          user_reset_password_page.fill_in_new_password("newsuperpassword").submit_new_password

          expect(user_reset_password_page).to have_logged_in_user
        end
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

      it "should allow a user to reset password with backup code instead of security key" do
        with_security_key(user) do
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
    end

    context "when user has TOTP, security key and backup codes configured" do
      fab!(:user_second_factor_totp) { Fabricate(:user_second_factor_totp, user:) }
      fab!(:user_second_factor_backup) { Fabricate(:user_second_factor_backup, user:) }

      it "should allow a user to toggle from security key to TOTP and between TOTP and backup codes" do
        with_security_key(user) do
          visit_reset_password_link

          user_reset_password_page.try_another_way

          expect(user_reset_password_page).to have_totp_description

          user_reset_password_page.use_backup_codes

          expect(user_reset_password_page).to have_backup_codes_description

          user_reset_password_page.use_totp

          expect(user_reset_password_page).to have_totp_description
        end
      end
    end

    context "when user has TOTP and security key configured but no backup codes" do
      fab!(:user_second_factor_totp) { Fabricate(:user_second_factor_totp, user:) }

      it "should allow a user to reset password with TOTP instead of security key" do
        with_security_key(user) do
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
end

describe "User resetting password", type: :system, dump_threads_on_failure: true do
  describe "when desktop" do
    include_examples "forgot password scenarios"
  end

  describe "when mobile", mobile: true do
    include_examples "forgot password scenarios"
  end
end
