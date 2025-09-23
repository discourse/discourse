# frozen_string_literal: true

describe "User preferences | Security", type: :system do
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

      expect(page).to have_selector(
        ".alert-error",
        text: "You are required to enable two-factor authentication before accessing this site.",
      )

      expect(page).to have_css(".user-preferences .totp")
      expect(page).to have_css(".user-preferences .security-key")

      find(".user-preferences .totp .btn.new-totp").click

      find(".dialog-body input#password").fill_in(with: password)
      find(".confirm-session .btn-primary").click

      expect(page).to have_css(".qr-code")
    end
  end

  context "when desktop" do
    include_examples "security keys"
    include_examples "passkeys"
    include_examples "enforced second factor"
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
  end
end
