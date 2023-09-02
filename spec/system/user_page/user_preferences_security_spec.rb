# frozen_string_literal: true

describe "User preferences for Security", type: :system do
  fab!(:user) { Fabricate(:user, email: "dude@pm.com", password: "kungfukenny") }
  let(:user_preferences_security_page) { PageObjects::Pages::UserPreferencesSecurity.new }
  let(:user_menu) { PageObjects::Components::UserMenu.new }

  before do
    Fabricate(:email_token, email: "dude@pm.com", user: user, confirmed: true)
    sign_in(user)
  end

  describe "Security keys" do
    it "adds a 2F security key and logs in with it" do
      # simulate browser credential authorization
      options = ::Selenium::WebDriver::VirtualAuthenticatorOptions.new
      page.driver.browser.add_virtual_authenticator(options)

      user_preferences_security_page.visit(user)
      user_preferences_security_page.visit_second_factor("kungfukenny")

      find(".security-key .new-security-key").click
      expect(user_preferences_security_page).to have_css("input#security-key-name")

      find(".modal-body input#security-key-name").fill_in(with: "First Key")
      find(".add-security-key").click

      expect(user_preferences_security_page).to have_css(".security-key .second-factor-item")

      user_menu.sign_out

      # login flow
      find(".d-header .login-button").click
      find("input#login-account-name").fill_in(with: user.username)
      find("input#login-account-password").fill_in(with: "kungfukenny")

      find(".modal-footer .btn-primary").click
      find("#security-key .btn-primary").click

      expect(page).to have_css(".header-dropdown-toggle.current-user")
    end
  end
end
