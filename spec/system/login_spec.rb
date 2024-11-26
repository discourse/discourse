# frozen_string_literal: true

require "rotp"

shared_examples "login scenarios" do |login_page_object|
  let(:login_form) { login_page_object }
  let(:activate_account) { PageObjects::Pages::ActivateAccount.new }
  let(:user_preferences_security_page) { PageObjects::Pages::UserPreferencesSecurity.new }
  fab!(:user) { Fabricate(:user, username: "john", password: "supersecurepassword") }
  fab!(:admin) { Fabricate(:admin, username: "admin", password: "supersecurepassword") }
  let(:user_menu) { PageObjects::Components::UserMenu.new }

  before { Jobs.run_immediately! }

  def wait_for_email_link(user, type)
    wait_for(timeout: 5) { ActionMailer::Base.deliveries.count != 0 }
    mail = ActionMailer::Base.deliveries.last
    expect(mail.to).to contain_exactly(user.email)
    if type == :reset_password
      mail.body.to_s[%r{/u/password-reset/\S+}]
    elsif type == :activation
      mail.body.to_s[%r{/u/activate-account/\S+}]
    elsif type == :email_login
      mail.body.to_s[%r{/session/email-login/\S+}]
    end
  end

  context "with username and password" do
    it "can login" do
      EmailToken.confirm(Fabricate(:email_token, user: user).token)

      login_form.open.fill(username: "john", password: "supersecurepassword").click_login
      expect(page).to have_css(".header-dropdown-toggle.current-user")
    end

    it "can login and activate account" do
      login_form.open.fill(username: "john", password: "supersecurepassword").click_login
      expect(page).to have_css(".not-activated-modal")
      login_form.click(".activation-controls button.resend")

      activation_link = wait_for_email_link(user, :activation)
      visit activation_link

      activate_account.click_activate_account
      activate_account.click_continue

      expect(page).to have_current_path("/")
      expect(page).to have_css(".header-dropdown-toggle.current-user")
    end

    it "redirects to the wizard after activating account" do
      login_form.open.fill(username: "admin", password: "supersecurepassword").click_login
      expect(page).to have_css(".not-activated-modal")
      login_form.click(".activation-controls button.resend")

      activation_link = wait_for_email_link(admin, :activation)
      visit activation_link

      activate_account.click_activate_account
      expect(page).to have_current_path(%r{/wizard})
    end

    it "shows error when when activation link is invalid" do
      login_form.open.fill(username: "john", password: "supersecurepassword").click_login
      expect(page).to have_css(".not-activated-modal")

      visit "/u/activate-account/invalid"

      activate_account.click_activate_account
      expect(activate_account).to have_error
    end

    it "displays the right message when user's email has been marked as expired" do
      password = "myawesomepassword"
      user.update!(password:)
      UserPasswordExpirer.expire_user_password(user)

      login_form.open.fill(username: user.username, password:).click_login

      expect(find(".alert-error")).to have_content(
        I18n.t("js.login.password_expired", reset_url: "/password-reset").gsub(/<.*?>/, ""),
      )

      find(".alert-error a").click

      # TODO: prefill username when fullpage
      if find("#username-or-email").value.blank?
        if page.has_css?("html.mobile-view", wait: 0)
          expect(page).to have_no_css(".d-modal.is-animating")
        end
        find("#username-or-email").fill_in(with: user.username)
      end

      find("button.forgot-password-reset").click

      reset_password_link = wait_for_email_link(user, :reset_password)
      expect(reset_password_link).to be_present
    end
  end

  context "with login link" do
    it "can login" do
      login_form.open.fill_username("john").email_login_link

      login_link = wait_for_email_link(user, :email_login)
      visit login_link

      find(".email-login-form .btn-primary").click
      expect(page).to have_css(".header-dropdown-toggle.current-user")
    end
  end

  context "when login is required" do
    before { SiteSetting.login_required = true }

    it "cannot browse annonymously" do
      visit "/"
      expect(page).to have_css(".login-welcome")
      expect(page).to have_css(".site-logo")
      find(".login-welcome .login-button").click

      EmailToken.confirm(Fabricate(:email_token, user: user).token)
      login_form.fill(username: "john", password: "supersecurepassword").click_login
      expect(page).to have_css(".header-dropdown-toggle.current-user")
    end
  end

  context "with two-factor authentication" do
    let!(:user_second_factor) { Fabricate(:user_second_factor_totp, user: user) }
    let!(:user_second_factor_backup) { Fabricate(:user_second_factor_backup, user: user) }
    fab!(:other_user) { Fabricate(:user, username: "jane", password: "supersecurepassword") }

    before do
      EmailToken.confirm(Fabricate(:email_token, user: user).token)
      EmailToken.confirm(Fabricate(:email_token, user: other_user).token)
    end

    context "when it is required" do
      before { SiteSetting.enforce_second_factor = "all" }

      it "requires to set 2FA after login" do
        login_form.open.fill(username: "jane", password: "supersecurepassword").click_login

        expect(page).to have_css(".header-dropdown-toggle.current-user")
        expect(page).to have_content(I18n.t("js.user.second_factor.enforced_notice"))
      end
    end

    it "can login with totp" do
      login_form.open.fill(username: "john", password: "supersecurepassword").click_login

      expect(page).to have_css(".second-factor")

      totp = ROTP::TOTP.new(user_second_factor.data).now
      find("#login-second-factor").fill_in(with: totp)
      login_form.click_login

      expect(page).to have_css(".header-dropdown-toggle.current-user")
    end

    it "can login with backup code" do
      login_form.open.fill(username: "john", password: "supersecurepassword").click_login

      expect(page).to have_css(".second-factor")

      find(".toggle-second-factor-method").click
      find(".second-factor-token-input").fill_in(with: "iAmValidBackupCode")
      login_form.click_login

      expect(page).to have_css(".header-dropdown-toggle.current-user")
    end

    it "can login with login link and totp" do
      login_form.open.fill_username("john").email_login_link

      login_link = wait_for_email_link(user, :email_login)
      visit login_link
      totp = ROTP::TOTP.new(user_second_factor.data).now
      find(".second-factor-token-input").fill_in(with: totp)
      find(".email-login-form .btn-primary").click

      expect(page).to have_css(".header-dropdown-toggle.current-user")
    end

    it "can login with login link and backup code" do
      login_form.open.fill_username("john").email_login_link

      login_link = wait_for_email_link(user, :email_login)
      visit login_link
      find(".toggle-second-factor-method").click
      find(".second-factor-token-input").fill_in(with: "iAmValidBackupCode")
      find(".email-login-form .btn-primary").click

      expect(page).to have_css(".header-dropdown-toggle.current-user")
    end

    it "can reset password with TOTP" do
      login_form.open.fill_username("john").forgot_password
      find("button.forgot-password-reset").click

      reset_password_link = wait_for_email_link(user, :reset_password)
      visit reset_password_link
      totp = ROTP::TOTP.new(user_second_factor.data).now
      find(".second-factor-token-input").fill_in(with: totp)
      find(".password-reset .btn-primary").click
      find("#new-account-password").fill_in(with: "newsuperpassword")
      find(".change-password-form .btn-primary").click

      expect(page).to have_css(".header-dropdown-toggle.current-user")
    end

    it "shows error correctly when TOTP code is invalid" do
      login_form.open.fill_username("john").forgot_password
      find("button.forgot-password-reset").click

      reset_password_link = wait_for_email_link(user, :reset_password)
      visit reset_password_link
      find(".second-factor-token-input").fill_in(with: "123456")
      find(".password-reset .btn-primary").click

      expect(page).to have_css(
        ".alert-error",
        text: "Invalid authentication code. Each code can only be used once.",
      )
      expect(page).to have_css(".second-factor-token-input")
    end

    it "can reset password with a backup code" do
      login_form.open.fill_username("john").forgot_password
      find("button.forgot-password-reset").click

      reset_password_link = wait_for_email_link(user, :reset_password)
      visit reset_password_link
      find(".toggle-second-factor-method").click
      find(".second-factor-token-input").fill_in(with: "iAmValidBackupCode")
      find(".password-reset .btn-primary").click
      find("#new-account-password").fill_in(with: "newsuperpassword")
      find(".change-password-form .btn-primary").click

      expect(page).to have_css(".header-dropdown-toggle.current-user")
    end
  end
end

describe "Login", type: :system do
  context "when desktop" do
    include_examples "login scenarios", PageObjects::Modals::Login.new
  end

  context "when mobile", mobile: true do
    include_examples "login scenarios", PageObjects::Modals::Login.new
  end

  context "when fullpage desktop" do
    before { SiteSetting.full_page_login = true }
    include_examples "login scenarios", PageObjects::Pages::Login.new
  end

  context "when fullpage mobile", mobile: true do
    before { SiteSetting.full_page_login = true }
    include_examples "login scenarios", PageObjects::Pages::Login.new
  end
end
