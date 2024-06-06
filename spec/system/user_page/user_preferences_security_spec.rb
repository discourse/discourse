# frozen_string_literal: true

describe "User preferences | Security", type: :system do
  fab!(:password) { "kungfukenny" }
  fab!(:email) { "email@user.com" }
  fab!(:user) { Fabricate(:user, email: email, password: password) }
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
      options = ::Selenium::WebDriver::VirtualAuthenticatorOptions.new
      authenticator = page.driver.browser.add_virtual_authenticator(options)

      user_preferences_security_page.visit(user)
      user_preferences_security_page.visit_second_factor(password)

      find(".security-key .new-security-key").click
      expect(user_preferences_security_page).to have_css("input#security-key-name")

      find(".d-modal__body input#security-key-name").fill_in(with: "First Key")
      find(".add-security-key").click

      expect(user_preferences_security_page).to have_css(".security-key .second-factor-item")

      user_menu.sign_out

      # login flow
      find(".d-header .login-button").click
      find("input#login-account-name").fill_in(with: user.username)
      find("input#login-account-password").fill_in(with: password)

      find(".d-modal__footer .btn-primary").click
      find("#security-key .btn-primary").click

      expect(page).to have_css(".header-dropdown-toggle.current-user")
    ensure
      # clear authenticator (otherwise it will interfere with other tests)
      authenticator&.remove!
    end
  end

  shared_examples "passkeys" do
    before { SiteSetting.enable_passkeys = true }

    it "adds a passkey and logs in with it" do
      options =
        ::Selenium::WebDriver::VirtualAuthenticatorOptions.new(
          user_verification: true,
          user_verified: true,
          resident_key: true,
        )
      authenticator = page.driver.browser.add_virtual_authenticator(options)

      page.driver.browser.manage.add_cookie(
        domain: Discourse.current_hostname,
        name: "destination_url",
        value: "/new",
        path: "/",
      )

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

      user_menu.sign_out

      # login with the key we just created
      # this triggers the conditional UI for passkeys
      # which uses the virtual authenticator
      find(".d-header .login-button").click

      expect(page).to have_css(".header-dropdown-toggle.current-user")

      # ensures that we are redirected to the destination_url cookie
      expect(page.driver.current_url).to include("/new")
    ensure
      # clear authenticator (otherwise it will interfere with other tests)
      authenticator&.remove!
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
end
