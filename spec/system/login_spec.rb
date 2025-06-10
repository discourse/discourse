# frozen_string_literal: true

require "rotp"

shared_examples "login scenarios" do
  let(:login_form) { PageObjects::Pages::Login.new }
  let(:activate_account) { PageObjects::Pages::ActivateAccount.new }
  let(:user_preferences_security_page) { PageObjects::Pages::UserPreferencesSecurity.new }
  fab!(:user) { Fabricate(:user, username: "john", password: "supersecurepassword") }
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, user: user, category: category) }
  fab!(:topic2) { Fabricate(:topic, user: user) }
  fab!(:admin) { Fabricate(:admin, username: "admin", password: "supersecurepassword") }
  let(:user_menu) { PageObjects::Components::UserMenu.new }

  before do
    SiteSetting.hide_email_address_taken = false
    Jobs.run_immediately!
  end

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

    it "can login with redirect" do
      EmailToken.confirm(Fabricate(:email_token, user: user).token)

      login_form
        .open_with_redirect("/about")
        .fill(username: "john", password: "supersecurepassword")
        .click_login
      expect(page).to have_current_path("/about")
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

      visit "/u/activate-account/123abc"

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

    it "redirects to a PM after login" do
      EmailToken.confirm(Fabricate(:email_token, user: user).token)

      group = Fabricate(:group, publish_read_state: true)
      Fabricate(:group_user, group: group, user: user)
      pm = Fabricate(:private_message_topic, allowed_groups: [group])
      Fabricate(:post, topic: pm, user: user, reads: 2, created_at: 1.day.ago)
      Fabricate(:group_private_message_topic, user: user, recipient_group: group)

      visit "/t/#{pm.id}"
      login_form.fill(username: "john", password: "supersecurepassword").click_login

      expect(page).to have_css(".header-dropdown-toggle.current-user")
      expect(page).to have_css("#topic-title")
      expect(page).to have_css(".private_message")
    end

    it "does not leak topics" do
      visit "/"

      expect(page).to have_css(".login-welcome")

      expect(page.body).not_to include(topic.title)
      expect(page.body).not_to include(topic2.title)
    end

    it "does not leak category metadata if homepage is /categories" do
      SiteSetting.top_menu = "categories|latest|new|unread|top"
      visit "/"

      expect(page).to have_css(".login-welcome")

      expect(page.body).not_to include(category.name)
    end
  end

  context "when login is not required" do
    before { SiteSetting.login_required = false }

    it "redirects to a PM after authentication" do
      EmailToken.confirm(Fabricate(:email_token, user: user).token)
      group = Fabricate(:group, publish_read_state: true)
      Fabricate(:group_user, group: group, user: user)
      pm = Fabricate(:private_message_topic, allowed_groups: [group])
      Fabricate(:post, topic: pm, user: user, reads: 2, created_at: 1.day.ago)
      Fabricate(:group_private_message_topic, user: user, recipient_group: group)

      visit "/t/#{pm.id}"
      find(".btn.login-button").click

      login_form.fill(username: "john", password: "supersecurepassword").click_login
      expect(page).to have_css(".header-dropdown-toggle.current-user")

      expect(page).to have_css("#topic-title")
      expect(page).to have_css(".private_message")
    end

    it "redirects to a public topic when hitting Reply then logging in" do
      EmailToken.confirm(Fabricate(:email_token, user: user).token)
      topic = Fabricate(:topic)
      Fabricate(:post, topic: topic, created_at: 1.day.ago)

      visit "/t/#{topic.id}"
      find(".topic-footer-main-buttons .btn-primary").click

      login_form.fill(username: "john", password: "supersecurepassword").click_login
      expect(page).to have_css(".header-dropdown-toggle.current-user")

      expect(page).to have_css("#topic-title")
    end

    context "with user api key and omniauth" do
      include OmniauthHelpers

      let :public_key do
        <<~TXT
    -----BEGIN PUBLIC KEY-----
    MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDh7BS7Ey8hfbNhlNAW/47pqT7w
    IhBz3UyBYzin8JurEQ2pY9jWWlY8CH147KyIZf1fpcsi7ZNxGHeDhVsbtUKZxnFV
    p16Op3CHLJnnJKKBMNdXMy0yDfCAHZtqxeBOTcCo1Vt/bHpIgiK5kmaekyXIaD0n
    w0z/BYpOgZ8QwnI5ZwIDAQAB
    -----END PUBLIC KEY-----
    TXT
      end

      let :private_key do
        <<~TXT
    -----BEGIN RSA PRIVATE KEY-----
    MIICWwIBAAKBgQDh7BS7Ey8hfbNhlNAW/47pqT7wIhBz3UyBYzin8JurEQ2pY9jW
    WlY8CH147KyIZf1fpcsi7ZNxGHeDhVsbtUKZxnFVp16Op3CHLJnnJKKBMNdXMy0y
    DfCAHZtqxeBOTcCo1Vt/bHpIgiK5kmaekyXIaD0nw0z/BYpOgZ8QwnI5ZwIDAQAB
    AoGAeHesbjzCivc+KbBybXEEQbBPsThY0Y+VdgD0ewif2U4UnNhzDYnKJeTZExwQ
    vAK2YsRDV3KbhljnkagQduvmgJyCKuV/CxZvbJddwyIs3+U2D4XysQp3e1YZ7ROr
    YlOIoekHCx1CNm6A4iImqGxB0aJ7Owdk3+QSIaMtGQWaPTECQQDz2UjJ+bomguNs
    zdcv3ZP7W3U5RG+TpInSHiJXpt2JdNGfHItozGJCxfzDhuKHK5Cb23bgldkvB9Xc
    p/tngTtNAkEA7S4cqUezA82xS7aYPehpRkKEmqzMwR3e9WeL7nZ2cdjZAHgXe49l
    3mBhidEyRmtPqbXo1Xix8LDuqik0IdnlgwJAQeYTnLnHS8cNjQbnw4C/ECu8Nzi+
    aokJ0eXg5A0tS4ttZvGA31Z0q5Tz5SdbqqnkT6p0qub0JZiZfCNNdsBe9QJAaGT5
    fJDwfGYW+YpfLDCV1bUFhMc2QHITZtSyxL0jmSynJwu02k/duKmXhP+tL02gfMRy
    vTMorxZRllgYeCXeXQJAEGRXR8/26jwqPtKKJzC7i9BuOYEagqj0nLG2YYfffCMc
    d3JGCf7DMaUlaUE8bJ08PtHRJFSGkNfDJLhLKSjpbw==
    -----END RSA PRIVATE KEY-----
    TXT
      end

      let :args do
        {
          scopes: "one_time_password",
          client_id: "x" * 32,
          auth_redirect: "discourse://auth_redirect",
          application_name: "foo",
          public_key: public_key,
          nonce: SecureRandom.hex,
        }
      end

      before do
        OmniAuth.config.test_mode = true
        SiteSetting.auth_skip_create_confirm = true
        SiteSetting.enable_google_oauth2_logins = true
        SiteSetting.enable_local_logins = false
      end

      after { reset_omniauth_config(:google_oauth2) }

      it "completes signup and redirects to the user api key authorization form" do
        mock_google_auth
        visit("/user-api-key/new?#{args.to_query}")

        expect(page).to have_css(".authorize-api-key .scopes")
      end

      it "redirects when navigating to login with redirect param" do
        mock_google_auth
        login_form.open_with_redirect("/about")
        expect(page).to have_current_path("/about")
      end
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

    it "can login with totp and redirect" do
      login_form
        .open_with_redirect("/about")
        .fill(username: "john", password: "supersecurepassword")
        .click_login

      expect(page).to have_css(".second-factor")

      totp = ROTP::TOTP.new(user_second_factor.data).now
      find("#login-second-factor").fill_in(with: totp)
      login_form.click_login

      expect(page).to have_current_path("/about")
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
    include_examples "login scenarios"
  end

  context "when mobile", mobile: true do
    include_examples "login scenarios"
  end
end
