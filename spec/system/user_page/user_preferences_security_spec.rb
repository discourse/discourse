# frozen_string_literal: true

describe "User preferences | Security" do
  fab!(:password) { "kungfukenny" }
  fab!(:email) { "email@user.com" }
  fab!(:admin)
  fab!(:user) { Fabricate(:user, email: email, password: password) }
  fab!(:staged_user) { Fabricate(:user, staged: true) }
  let(:user_preferences_security_page) { PageObjects::Pages::UserPreferencesSecurity.new }
  let(:user_menu) { PageObjects::Components::UserMenu.new }

  before do
    user.activate
    # testing the enforced 2FA flow requires a user that was created > 5 minutes ago
    user.created_at = 6.minutes.ago
    user.save!
    sign_in(user)

    # system specs run on their own host + port
    DiscourseWebauthn.stubs(:origin).returns(current_host + ":" + Capybara.server_port.to_s)
  end

  shared_examples "security keys" do
    it "adds a 2FA security key and logs in with it" do
      SiteSetting.enable_local_logins_via_code = false

      with_virtual_authenticator do
        confirm_session_modal =
          user_preferences_security_page
            .visit(user)
            .click_manage_2fa_authentication
            .click_forgot_password

        expect(confirm_session_modal).to have_forgot_password_email_sent

        confirm_session_modal.submit_password(password)

        expect(page).to have_current_path("/u/#{user.username}/preferences/second-factor")

        find(".security-key .new-security-key").click
        expect(user_preferences_security_page).to have_css("input#security-key-name")

        find(".d-modal__body input#security-key-name").fill_in(with: "First Key")
        find(".add-security-key").click

        expect(user_preferences_security_page).to have_css(".security-key .second-factor-item")

        user_menu.sign_out

        # puts <<~STRING
        # public_key_base64 = \"#{user.second_factor_security_keys.first.public_key}\"
        # private_key_string = \"#{authenticator.credentials.first.private_key}\"
        # STRING

        # login flow
        find(".d-header .login-button").click
        find("input#login-account-name").fill_in(with: user.username)
        find("input#login-account-password").fill_in(with: password)

        find("#login-button.btn-primary").click
        find("#security-key .btn-primary").click

        expect(page).to have_css(".header-dropdown-toggle.current-user")
      end
    end
  end

  shared_examples "passkeys" do
    before { SiteSetting.enable_passkeys = true }

    it "adds a passkey, removes user password, logs in with passkey" do
      # A password can only be removed once it is older than a login token
      user.user_password.update_columns(created_at: 1.hour.ago)

      with_virtual_authenticator(
        hasUserVerification: true,
        hasResidentKey: true,
        isUserVerified: true,
      ) do
        user_preferences_security_page.visit(user)

        find(".pref-passkeys__add .btn").click
        expect(user_preferences_security_page).to have_css("input#password")

        find(".dialog-body input#password").fill_in(with: password)
        find(".confirm-session .btn-primary").click

        expect(user_preferences_security_page).to have_css(".rename-passkey__form")

        find(".dialog-close").click

        expect(user_preferences_security_page).to have_css(".pref-passkeys__rows .row")

        select_kit = PageObjects::Components::SelectKit.new(".passkey-options-dropdown")
        select_kit.expand
        select_kit.select_row_by_name("Delete")

        # confirm deletion screen shown without requiring session confirmation
        # since this was already done when adding the passkey
        expect(user_preferences_security_page).to have_css(".dialog-footer .btn-danger")

        # close the dialog (don't delete the key, we need it to login in the next step)
        find(".dialog-close").click

        find("#remove-password-link").click
        # already confirmed session for the passkey, so this will go straight for the confirmation dialog
        find(".dialog-footer .btn-danger").click
        expect(user_preferences_security_page).to have_no_css("#remove-password-link")

        user_menu.sign_out

        # ensures /hot isn't the homepage (otherwise the test below is pointless)
        expect(SiteSetting.top_menu_items.first).not_to eq("hot")

        # visit /hot to ensure we have a destination_url cookie set
        visit("/hot")

        # login with the key we just created
        # this triggers the conditional UI for passkeys
        # which uses the virtual authenticator
        find(".d-header .login-button").click

        expect(page).to have_css(".header-dropdown-toggle.current-user")

        # ensures that we are redirected to the destination_url cookie
        expect(page.driver.current_url).to include("/hot")
      end
    end
  end

  shared_examples "enforced second factor" do
    it "allows user to add 2FA" do
      SiteSetting.enforce_second_factor = "all"

      visit("/")

      expect(page).to have_current_path("/u/#{user.username}/preferences/second-factor")
      expect(page).to have_selector(
        ".alert-error",
        text: I18n.t("js.user.second_factor.enforced_notice"),
      )
      expect(page).to have_no_css(".new-totp")

      click_button I18n.t("js.user.confirm_access.title")
      PageObjects::Modals::ConfirmSession.new.submit_password(password)

      expect(page).to have_css(".user-preferences .security-key")
      find(".user-preferences .totp .new-totp").click

      expect(page).to have_css(".qr-code")
    end
  end

  context "when desktop" do
    include_examples "security keys"
    include_examples "passkeys"
    include_examples "enforced second factor"

    it "shows backup codes button after adding first TOTP" do
      user_preferences_security_page.visit(user).visit_second_factor(user, password)

      expect(page).to have_text(I18n.t("js.user.second_factor_backup.enable_prerequisites"))
      expect(page).to have_no_css(".new-second-factor-backup")

      find(".totp .new-totp").click
      find(".show-second-factor-key").click
      totp = ROTP::TOTP.new(find(".second-factor-key").text.gsub(/\s+/, ""))
      find("#second-factor-name").fill_in(with: "My Authenticator")
      find("#second-factor-token").fill_in(with: totp.now)
      find(".add-totp").click

      expect(page).to have_css(".new-second-factor-backup")
      expect(page).to have_no_text(I18n.t("js.user.second_factor_backup.enable_prerequisites"))
    end

    it "allows a passwordless user to confirm their session with an email code" do
      Jobs.run_immediately!
      SiteSetting.enable_local_logins_via_email = true
      passwordless_user = Fabricate(:user, password: nil, email: "passwordless@user.com")
      passwordless_user.activate
      sign_in(passwordless_user)

      confirm_session_modal =
        user_preferences_security_page.visit(passwordless_user).click_manage_2fa_authentication

      expect(page).to have_no_css(".confirm-session input#password")

      confirm_session_modal.click_email_code
      expect(page).to have_css(".confirm-session .d-otp-input")

      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to contain_exactly(passwordless_user.email)
      code = mail.subject[/(\d{6})/, 1]

      confirm_session_modal.submit_email_code(code)

      expect(page).to have_current_path(
        "/u/#{passwordless_user.username}/preferences/second-factor",
      )
      expect(page).to have_css(".totp .new-totp")
    end

    it "skips the confirm session modal when the user recently logged in" do
      visit("/")
      user_menu.sign_out

      find(".d-header .login-button").click
      find("input#login-account-name").fill_in(with: user.username)
      find("input#login-account-password").fill_in(with: password)
      find("#login-button.btn-primary").click

      expect(page).to have_css(".header-dropdown-toggle.current-user")

      user_preferences_security_page.visit(user)
      click_button "Manage Two-Factor Authentication"

      expect(page).to have_current_path("/u/#{user.username}/preferences/second-factor")
      expect(page).to have_no_css(".confirm-session")
      expect(page).to have_css(".totp .new-totp")
    end
  end

  context "when mobile", mobile: true do
    include_examples "security keys"
    include_examples "passkeys"
    include_examples "enforced second factor"
  end

  context "when viewing a user's page as an admin" do
    before { sign_in(admin) }

    describe "password reset" do
      it "disables the password reset button for staged users" do
        visit("/u/#{staged_user.username}/preferences/security")

        expect(page.find("#change-password-button")).to be_disabled
        expect(page).to have_css(
          ".instructions",
          text: I18n.t("js.user.change_password.staged_user"),
        )
      end

      it "does not disable password reset for non-staged users" do
        visit("/u/#{user.username}/preferences/security")

        expect(page.find("#change-password-button")).not_to be_disabled
        expect(page).to have_no_css(
          ".instructions",
          text: I18n.t("js.user.change_password.staged_user"),
        )
      end
    end

    it "logs the user's devices out without logging the admin out" do
      UserAuthToken.generate!(user_id: user.id, user_agent: "Firefox", client_ip: "1.1.1.1")

      user_preferences_security_page.visit(user)

      expect(user_preferences_security_page).to have_auth_token("Firefox")

      dropdown = user_preferences_security_page.auth_token_dropdown
      dropdown.expand

      expect(dropdown).to have_no_option_value("notYou")

      dropdown.select_row_by_value("logOut")

      expect(user_preferences_security_page).to have_no_auth_token("Firefox")
      expect(user_preferences_security_page).to have_auth_token

      user_preferences_security_page.log_out_all_devices

      expect(user_preferences_security_page).to have_no_auth_token

      page.refresh

      expect(page).to have_current_path("/u/#{user.username}/preferences/security")
      expect(user_preferences_security_page).to have_auth_tokens_section
      expect(user_preferences_security_page).to have_no_auth_token
    end
  end
end
