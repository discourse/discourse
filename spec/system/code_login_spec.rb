# frozen_string_literal: true

describe "Login and signup via email code" do
  include ThemeScreenshotMarker

  before do
    SiteSetting.enable_local_logins_via_code = true
    Jobs.run_immediately!
  end

  def fill_code(code)
    find(".d-otp-input").fill_in(with: code)
  end

  def latest_emailed_code(email)
    wait_for(timeout: 10) { ActionMailer::Base.deliveries.count != 0 }
    mail = ActionMailer::Base.deliveries.last
    expect(mail.to).to contain_exactly(email)
    mail.subject[/(\d{6})/, 1]
  end

  def request_code(email, path: "/login")
    visit(path)
    find(".code-login-form__email-step input[type='email']").fill_in(with: email)
    find(".code-login-form__continue").click
    expect(page).to have_css(".code-login-form__code-step")
  end

  context "when signing up with a new email" do
    it "creates an account and logs in" do
      visit("/signup")
      expect(page).to have_css(".code-login-form__email-step")
      screenshot_marker(label: "code-signup-email-step")

      find(".code-login-form__email-step input[type='email']").fill_in(
        with: "new.person@example.com",
      )
      find(".code-login-form__continue").click
      expect(page).to have_css(".code-login-form__code-step")
      screenshot_marker(label: "code-signup-code-step")

      fill_code(latest_emailed_code("new.person@example.com"))

      expect(page).to have_css(".header-dropdown-toggle.current-user")

      user = User.find_by_email("new.person@example.com")
      expect(user).to be_active
      expect(user.user_password).to be_nil
    end
  end

  context "when logging in as an existing user" do
    fab!(:user)

    it "logs in without a password" do
      request_code(user.email)
      expect(page).to have_css(".code-login-form__resend[disabled]")

      fill_code(latest_emailed_code(user.email))

      expect(page).to have_css(".header-dropdown-toggle.current-user")
      expect(User.find_by_email(user.email)).to eq(user)
    end

    it "shows an error for a wrong code, then accepts the correct one" do
      request_code(user.email)
      code = latest_emailed_code(user.email)
      wrong_code = code == "000000" ? "000001" : "000000"

      fill_code(wrong_code)
      expect(page).to have_css(
        ".code-login-form__error",
        text: I18n.t("email_login_code.invalid_code"),
      )
      screenshot_marker(label: "code-login-wrong-code")

      fill_code(code)
      expect(page).to have_css(".header-dropdown-toggle.current-user")
    end
  end

  context "with the password form toggle" do
    fab!(:user) { Fabricate(:user, password: "supersecurepassword") }

    it "can switch to password login and back" do
      EmailToken.confirm(Fabricate(:email_token, user: user).token)

      visit("/login")
      expect(page).to have_css(".code-login-form__email-step")
      screenshot_marker(label: "code-login-email-step")

      find(".code-login-form__password-toggle").click
      expect(page).to have_css("#login-account-name")
      screenshot_marker(label: "code-login-password-form")

      find(".login-page-cta__code-login").click
      expect(page).to have_css(".code-login-form__email-step")

      find(".code-login-form__password-toggle").click
      expect(page).to have_css("#login-account-name")

      find("#login-account-name").fill_in(with: user.username)
      find("#login-account-password").fill_in(with: "supersecurepassword")
      find("#login-button").click

      expect(page).to have_css(".header-dropdown-toggle.current-user")
    end
  end

  context "when the setting is disabled" do
    before { SiteSetting.enable_local_logins_via_code = false }

    it "shows the regular login form" do
      visit("/login")

      expect(page).to have_css("#login-account-name")
      expect(page).to have_no_css(".code-login-form")
    end
  end
end
