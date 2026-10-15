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
    DiscourseWebauthn.stubs(:origin).returns(
      URI.parse(browser_page.url).then { |uri| "#{uri.scheme}://#{uri.host}" } + ":" +
        Capybara.server_port.to_s,
    )
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

        expect(browser_page).to PlaywrightMatchers.have_url(
          "/u/#{user.username}/preferences/second-factor",
        )

        browser_root.locator(".security-key .new-security-key").filter(visible: true).click
        expect(
          user_preferences_security_page.locator("input#security-key-name").filter(visible: true),
        ).not_to PlaywrightMatchers.have_count(0)

        browser_root
          .locator(".d-modal__body input#security-key-name")
          .filter(visible: true)
          .fill("First Key")
        browser_root.locator(".add-security-key").filter(visible: true).click

        expect(
          user_preferences_security_page.locator(".security-key .second-factor-item").filter(
            visible: true,
          ),
        ).not_to PlaywrightMatchers.have_count(0)

        user_menu.sign_out

        # puts <<~STRING
        # public_key_base64 = \"#{user.second_factor_security_keys.first.public_key}\"
        # private_key_string = \"#{authenticator.credentials.first.private_key}\"
        # STRING

        # login flow
        browser_root.locator(".d-header .login-button").filter(visible: true).click
        browser_root.locator("input#login-account-name").filter(visible: true).fill(user.username)
        browser_root.locator("input#login-account-password").filter(visible: true).fill(password)

        browser_root.locator("#login-button.btn-primary").filter(visible: true).click
        browser_root.locator("#security-key .btn-primary").filter(visible: true).click

        expect(
          browser_root.locator(".header-dropdown-toggle.current-user").filter(visible: true),
        ).not_to PlaywrightMatchers.have_count(0)
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

        browser_root.locator(".pref-passkeys__add .btn").filter(visible: true).click
        expect(
          user_preferences_security_page.locator("input#password").filter(visible: true),
        ).not_to PlaywrightMatchers.have_count(0)

        browser_root.locator(".dialog-body input#password").filter(visible: true).fill(password)
        browser_root.locator(".confirm-session .btn-primary").filter(visible: true).click

        expect(
          user_preferences_security_page.locator(".rename-passkey__form").filter(visible: true),
        ).not_to PlaywrightMatchers.have_count(0)

        browser_root.locator(".dialog-close").filter(visible: true).click

        expect(
          user_preferences_security_page.locator(".pref-passkeys__rows .row").filter(visible: true),
        ).not_to PlaywrightMatchers.have_count(0)

        select_kit = PageObjects::Components::SelectKit.new(".passkey-options-dropdown")
        select_kit.expand
        select_kit.select_row_by_name("Delete")

        # confirm deletion screen shown without requiring session confirmation
        # since this was already done when adding the passkey
        expect(
          user_preferences_security_page.locator(".dialog-footer .btn-danger").filter(
            visible: true,
          ),
        ).not_to PlaywrightMatchers.have_count(0)

        # close the dialog (don't delete the key, we need it to login in the next step)
        browser_root.locator(".dialog-close").filter(visible: true).click

        browser_root.locator("#remove-password-link").filter(visible: true).click
        # already confirmed session for the passkey, so this will go straight for the confirmation dialog
        browser_root.locator(".dialog-footer .btn-danger").filter(visible: true).click
        expect(
          user_preferences_security_page.locator("#remove-password-link").filter(visible: true),
        ).to PlaywrightMatchers.have_count(0)

        user_menu.sign_out

        # ensures /hot isn't the homepage (otherwise the test below is pointless)
        expect(SiteSetting.top_menu_items.first).not_to eq("hot")

        # visit /hot to ensure we have a destination_url cookie set
        browser_page.goto("/hot").tap { SystemBrowserBootstrap.wait_for(browser_page) }

        # login with the key we just created
        # this triggers the conditional UI for passkeys
        # which uses the virtual authenticator
        browser_root.locator(".d-header .login-button").filter(visible: true).click

        expect(
          browser_root.locator(".header-dropdown-toggle.current-user").filter(visible: true),
        ).not_to PlaywrightMatchers.have_count(0)

        # ensures that we are redirected to the destination_url cookie
        expect(browser_page.url).to include("/hot")
      end
    end
  end

  shared_examples "enforced second factor" do
    it "allows user to add 2FA" do
      SiteSetting.enforce_second_factor = "all"

      browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }

      expect(
        browser_root.locator(".alert-error").filter(visible: true),
      ).to PlaywrightMatchers.contain_text(
        [
          browser_text_pattern(
            "You are required to enable two-factor authentication before accessing this site.",
          ),
        ],
        useInnerText: true,
      )

      expect(
        browser_root.locator(".user-preferences .totp").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
      expect(
        browser_root.locator(".user-preferences .security-key").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)

      browser_root.locator(".user-preferences .totp .btn.new-totp").filter(visible: true).click

      browser_root.locator(".dialog-body input#password").filter(visible: true).fill(password)
      browser_root.locator(".confirm-session .btn-primary").filter(visible: true).click

      expect(
        browser_root.locator(".qr-code").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
    end
  end

  context "when desktop" do
    include_examples "security keys"
    include_examples "passkeys"
    include_examples "enforced second factor"

    it "shows backup codes button after adding first TOTP" do
      user_preferences_security_page.visit(user).visit_second_factor(user, password)

      expect(browser_content).to PlaywrightMatchers.contain_text(
        browser_text_pattern(I18n.t("js.user.second_factor_backup.enable_prerequisites")),
        useInnerText: true,
      )
      expect(
        browser_root.locator(".new-second-factor-backup").filter(visible: true),
      ).to PlaywrightMatchers.have_count(0)

      browser_root.locator(".totp .new-totp").filter(visible: true).click
      browser_root.locator(".show-second-factor-key").filter(visible: true).click
      totp =
        ROTP::TOTP.new(
          browser_root
            .locator(".second-factor-key")
            .filter(visible: true)
            .inner_text
            .strip
            .gsub(/\s+/, ""),
        )
      browser_root.locator("#second-factor-name").filter(visible: true).fill("My Authenticator")
      browser_root.locator("#second-factor-token").filter(visible: true).fill(totp.now)
      browser_root.locator(".add-totp").filter(visible: true).click

      expect(
        browser_root.locator(".new-second-factor-backup").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
      expect(browser_content).not_to PlaywrightMatchers.contain_text(
        browser_text_pattern(I18n.t("js.user.second_factor_backup.enable_prerequisites")),
        useInnerText: true,
      )
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
        browser_page
          .goto("/u/#{staged_user.username}/preferences/security")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }

        expect(
          browser_root.locator("#change-password-button").filter(visible: true),
        ).to PlaywrightMatchers.be_disabled
        expect(
          browser_root.locator(".instructions").filter(visible: true),
        ).to PlaywrightMatchers.contain_text(
          [browser_text_pattern(I18n.t("js.user.change_password.staged_user"))],
          useInnerText: true,
        )
      end

      it "does not disable password reset for non-staged users" do
        browser_page
          .goto("/u/#{user.username}/preferences/security")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }

        expect(
          browser_root.locator("#change-password-button").filter(visible: true),
        ).not_to PlaywrightMatchers.be_disabled
        expect(
          browser_root.locator(".instructions").filter(visible: true),
        ).not_to PlaywrightMatchers.contain_text(
          [browser_text_pattern(I18n.t("js.user.change_password.staged_user"))],
          useInnerText: true,
        )
      end
    end
  end
end
