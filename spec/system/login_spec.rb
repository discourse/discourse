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
    SiteSetting.enable_local_logins_via_code = false
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
      expect(
        browser_root.locator(".header-dropdown-toggle.current-user").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
    end

    it "can login with redirect" do
      EmailToken.confirm(Fabricate(:email_token, user: user).token)

      login_form
        .open_with_redirect("/about")
        .fill(username: "john", password: "supersecurepassword")
        .click_login
      expect(browser_page).to PlaywrightMatchers.have_url("/about")
    end

    it "can login and activate account" do
      login_form.open.fill(username: "john", password: "supersecurepassword").click_login
      expect(
        browser_root.locator(".not-activated-modal").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
      login_form.click(".activation-controls button.resend")

      activation_link = wait_for_email_link(user, :activation)
      browser_page.goto(activation_link).tap { SystemBrowserBootstrap.wait_for(browser_page) }

      activate_account.click_activate_account
      activate_account.click_continue

      expect(browser_page).to PlaywrightMatchers.have_url("/")
      expect(
        browser_root.locator(".header-dropdown-toggle.current-user").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
    end

    it "redirects to the wizard after activating account" do
      login_form.open.fill(username: "admin", password: "supersecurepassword").click_login
      expect(
        browser_root.locator(".not-activated-modal").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
      login_form.click(".activation-controls button.resend")

      activation_link = wait_for_email_link(admin, :activation)
      browser_page.goto(activation_link).tap { SystemBrowserBootstrap.wait_for(browser_page) }

      activate_account.click_activate_account
      expect(browser_page).to PlaywrightMatchers.have_url(%r{/wizard})
    end

    it "shows error when when activation link is invalid" do
      login_form.open.fill(username: "john", password: "supersecurepassword").click_login
      expect(
        browser_root.locator(".not-activated-modal").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)

      browser_page
        .goto("/u/activate-account/123abc")
        .tap { SystemBrowserBootstrap.wait_for(browser_page) }

      activate_account.click_activate_account
      expect(activate_account).to have_error
    end

    it "displays the right message when user's email has been marked as expired" do
      password = "myawesomepassword"
      user.update!(password:)
      UserPasswordExpirer.expire_user_password(user)

      login_form.open.fill(username: user.username, password:).click_login

      expect(
        browser_root.locator(".alert-error").filter(visible: true),
      ).to PlaywrightMatchers.contain_text(
        browser_text_pattern(
          I18n.t("js.login.password_expired", reset_url: "/password-reset").gsub(/<.*?>/, ""),
        ),
        useInnerText: true,
      )

      browser_root.locator(".alert-error a").filter(visible: true).click

      # TODO: prefill username when fullpage
      if browser_root.locator("#username-or-email").filter(visible: true).input_value.blank?
        browser_root.locator("#username-or-email").filter(visible: true).fill(user.username)
      end

      browser_root.locator("button.forgot-password-reset").filter(visible: true).click

      reset_password_link = wait_for_email_link(user, :reset_password)
      expect(reset_password_link).to be_present
    end
  end

  context "with login link" do
    # The email login link is replaced by the code login flow when
    # enable_local_logins_via_code is on, which has its own spec.
    before { SiteSetting.enable_local_logins_via_code = false }

    it "can login" do
      login_form.open.fill_username("john").email_login_link

      login_link = wait_for_email_link(user, :email_login)
      browser_page.goto(login_link).tap { SystemBrowserBootstrap.wait_for(browser_page) }

      browser_root.locator(".email-login-form .btn-primary").filter(visible: true).click
      expect(
        browser_root.locator(".header-dropdown-toggle.current-user").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
    end
  end

  context "when login is required" do
    before { SiteSetting.login_required = true }

    it "keeps topics private until the user logs in" do
      browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }

      screenshot_marker(label: "login-required")
      expect(
        browser_root.locator(".login-welcome").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
      expect(
        browser_root.locator(".site-logo").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
      expect(browser_page.content).not_to include(topic.title)
      expect(browser_page.content).not_to include(topic2.title)

      browser_root.locator(".login-welcome .login-button").filter(visible: true).click

      screenshot_marker(label: "login-form")

      EmailToken.confirm(Fabricate(:email_token, user: user).token)
      login_form.fill(username: "john", password: "supersecurepassword").click_login
      expect(
        browser_root.locator(".header-dropdown-toggle.current-user").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
    end

    it "redirects to a PM after login" do
      EmailToken.confirm(Fabricate(:email_token, user: user).token)

      group = Fabricate(:group, publish_read_state: true)
      Fabricate(:group_user, group: group, user: user)
      pm = Fabricate(:private_message_topic, allowed_groups: [group])
      Fabricate(:post, topic: pm, user: user, reads: 2, created_at: 1.day.ago)
      Fabricate(:group_private_message_topic, user: user, recipient_group: group)

      browser_page.goto("/t/#{pm.id}").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      login_form.fill(username: "john", password: "supersecurepassword").click_login

      expect(
        browser_root.locator(".header-dropdown-toggle.current-user").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
      expect(
        browser_root.locator("#topic-title").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
      expect(
        browser_root.locator(".private_message").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
    end

    it "redirects to a route with a query parameters after login and keeps the query parameters" do
      EmailToken.confirm(Fabricate(:email_token, user: user).token)

      category = Fabricate(:category)

      browser_page
        .goto("/new-topic?category_id=#{category.id}")
        .tap { SystemBrowserBootstrap.wait_for(browser_page) }
      login_form.fill(username: "john", password: "supersecurepassword").click_login

      expect(browser_page).to PlaywrightMatchers.have_url("/new-topic?category_id=#{category.id}")
    end

    it "does not leak category metadata if homepage is /categories" do
      SiteSetting.top_menu = "categories|latest|new|top"
      browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }

      expect(
        browser_root.locator(".login-welcome").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)

      expect(browser_page.content).not_to include(category.name)
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

      browser_page.goto("/t/#{pm.id}").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      browser_root.locator(".btn.login-button").filter(visible: true).click

      login_form.fill(username: "john", password: "supersecurepassword").click_login
      expect(
        browser_root.locator(".header-dropdown-toggle.current-user").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)

      expect(
        browser_root.locator("#topic-title").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
      expect(
        browser_root.locator(".private_message").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
    end

    it "redirects to a public topic when hitting Reply then logging in" do
      EmailToken.confirm(Fabricate(:email_token, user: user).token)
      topic = Fabricate(:topic)
      Fabricate(:post, topic: topic, created_at: 1.day.ago)

      browser_page.goto("/t/#{topic.id}").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      browser_root.locator(".topic-footer-main-buttons .btn-primary").filter(visible: true).click

      login_form.fill(username: "john", password: "supersecurepassword").click_login
      expect(
        browser_root.locator(".header-dropdown-toggle.current-user").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)

      expect(
        browser_root.locator("#topic-title").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
    end

    it "redirects to a route with a query parameters after login and keeps the query parameters" do
      EmailToken.confirm(Fabricate(:email_token, user: user).token)

      category = Fabricate(:category)

      browser_page
        .goto("/new-topic?category_id=#{category.id}")
        .tap { SystemBrowserBootstrap.wait_for(browser_page) }
      login_form.fill(username: "john", password: "supersecurepassword").click_login

      expect(browser_page).to PlaywrightMatchers.have_url("/new-topic?category_id=#{category.id}")
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
        enable_auth_provider(:google_oauth2)
        SiteSetting.enable_local_logins = false
      end

      after { reset_omniauth_config(:google_oauth2) }

      it "completes signup and redirects to the user api key authorization form" do
        mock_google_auth
        browser_page
          .goto("/user-api-key/new?#{args.to_query}")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }

        expect(
          browser_root.locator(".authorize-api-key__scopes").filter(visible: true),
        ).not_to PlaywrightMatchers.have_count(0)
      end

      it "redirects when navigating to login with redirect param" do
        mock_google_auth
        login_form.open_with_redirect("/about")
        expect(browser_page).to PlaywrightMatchers.have_url("/about")
      end
    end
  end

  context "with two-factor authentication" do
    let(:forgot_password_modal) { PageObjects::Modals::ForgotPassword.new }
    let(:reset_password_page) { PageObjects::Pages::UserResetPassword.new }
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

        expect(
          browser_root.locator(".header-dropdown-toggle.current-user").filter(visible: true),
        ).not_to PlaywrightMatchers.have_count(0)
        expect(browser_content).to PlaywrightMatchers.contain_text(
          browser_text_pattern(I18n.t("js.user.second_factor.enforced_notice")),
          useInnerText: true,
        )
      end
    end

    it "can login with totp" do
      login_form.open.fill(username: "john", password: "supersecurepassword").click_login

      expect(
        browser_root.locator(".second-factor").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)

      totp = ROTP::TOTP.new(user_second_factor.data).now
      browser_root.locator("#login-second-factor").filter(visible: true).fill(totp)

      expect(
        browser_root.locator(".header-dropdown-toggle.current-user").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
    end

    it "can login with totp and redirect" do
      login_form
        .open_with_redirect("/about")
        .fill(username: "john", password: "supersecurepassword")
        .click_login

      expect(
        browser_root.locator(".second-factor").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)

      totp = ROTP::TOTP.new(user_second_factor.data).now
      browser_root.locator("#login-second-factor").filter(visible: true).fill(totp)

      expect(browser_page).to PlaywrightMatchers.have_url("/about")
    end

    it "can login with backup code" do
      login_form.open.fill(username: "john", password: "supersecurepassword").click_login

      expect(
        browser_root.locator(".second-factor").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)

      browser_root.locator(".toggle-second-factor-method").filter(visible: true).click
      browser_root
        .locator(".second-factor-token-input")
        .filter(visible: true)
        .fill("iAmValidBackupCode")
      login_form.click_login

      expect(
        browser_root.locator(".header-dropdown-toggle.current-user").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
    end

    context "with login link" do
      # The email login link is replaced by the code login flow when
      # enable_local_logins_via_code is on, which has its own spec.
      before { SiteSetting.enable_local_logins_via_code = false }

      it "can login with login link and totp" do
        login_form.open.fill_username("john").email_login_link

        login_link = wait_for_email_link(user, :email_login)
        browser_page.goto(login_link).tap { SystemBrowserBootstrap.wait_for(browser_page) }
        totp = ROTP::TOTP.new(user_second_factor.data).now
        browser_root.locator(".second-factor-token-input").filter(visible: true).fill(totp)
        browser_root.locator(".email-login-form .btn-primary").filter(visible: true).click

        expect(
          browser_root.locator(".header-dropdown-toggle.current-user").filter(visible: true),
        ).not_to PlaywrightMatchers.have_count(0)
      end

      it "can login with login link and backup code" do
        login_form.open.fill_username("john").email_login_link

        login_link = wait_for_email_link(user, :email_login)
        browser_page.goto(login_link).tap { SystemBrowserBootstrap.wait_for(browser_page) }
        browser_root.locator(".toggle-second-factor-method").filter(visible: true).click
        browser_root
          .locator(".second-factor-token-input")
          .filter(visible: true)
          .fill("iAmValidBackupCode")
        browser_root.locator(".email-login-form .btn-primary").filter(visible: true).click

        expect(
          browser_root.locator(".header-dropdown-toggle.current-user").filter(visible: true),
        ).not_to PlaywrightMatchers.have_count(0)
      end
    end

    it "can reset password with an email code and TOTP" do
      SiteSetting.enable_local_logins_via_code = true

      login_form.open.fill_username("john").forgot_password
      forgot_password_modal.request_reset

      wait_for(timeout: 5) { ActionMailer::Base.deliveries.count != 0 }
      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to contain_exactly(user.email)
      forgot_password_modal.submit_code(mail.subject[/(\d{6})/, 1])

      expect(reset_password_page).to have_totp_description
      reset_password_page.fill_in_totp(ROTP::TOTP.new(user_second_factor.data).now).submit_totp
      reset_password_page.fill_in_new_password("newsuperpassword").submit_new_password

      expect(reset_password_page).to have_logged_in_user
    end

    it "lets the user retry an invalid TOTP code and reset their password" do
      login_form.open.fill_username("john").forgot_password
      browser_root.locator("button.forgot-password-reset").filter(visible: true).click

      reset_password_link = wait_for_email_link(user, :reset_password)
      browser_page.goto(reset_password_link).tap { SystemBrowserBootstrap.wait_for(browser_page) }
      browser_root.locator(".second-factor-token-input").filter(visible: true).fill("123456")
      browser_root.locator(".password-reset .btn-primary").filter(visible: true).click

      expect(
        browser_root.locator(".alert-error").filter(visible: true),
      ).to PlaywrightMatchers.contain_text(
        [browser_text_pattern("Invalid authentication code. Each code can only be used once.")],
        useInnerText: true,
      )
      expect(
        browser_root.locator(".second-factor-token-input").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)

      totp = ROTP::TOTP.new(user_second_factor.data).now
      browser_root.locator(".second-factor-token-input").filter(visible: true).fill(totp)
      browser_root.locator(".password-reset .btn-primary").filter(visible: true).click
      browser_root.locator("#new-account-password").filter(visible: true).fill("newsuperpassword")
      browser_root.locator(".change-password-form .btn-primary").filter(visible: true).click

      expect(
        browser_root.locator(".header-dropdown-toggle.current-user").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
    end

    it "can reset password with a backup code" do
      login_form.open.fill_username("john").forgot_password
      browser_root.locator("button.forgot-password-reset").filter(visible: true).click

      reset_password_link = wait_for_email_link(user, :reset_password)
      browser_page.goto(reset_password_link).tap { SystemBrowserBootstrap.wait_for(browser_page) }
      browser_root.locator(".toggle-second-factor-method").filter(visible: true).click
      browser_root
        .locator(".second-factor-token-input")
        .filter(visible: true)
        .fill("iAmValidBackupCode")
      browser_root.locator(".password-reset .btn-primary").filter(visible: true).click
      browser_root.locator("#new-account-password").filter(visible: true).fill("newsuperpassword")
      browser_root.locator(".change-password-form .btn-primary").filter(visible: true).click

      expect(
        browser_root.locator(".header-dropdown-toggle.current-user").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
    end
  end
end

describe "Login" do
  context "when desktop" do
    include_examples "login scenarios"
  end

  context "when mobile", mobile: true do
    include_examples "login scenarios"
  end
end
