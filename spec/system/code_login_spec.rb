# frozen_string_literal: true

require "rotp"

describe "Login via email code" do
  include ThemeScreenshotMarker

  fab!(:user) { Fabricate(:user, password: "supersecurepassword") }

  before do
    SiteSetting.enable_local_logins_via_email = true
    SiteSetting.enable_local_logins_via_code = true
    Jobs.run_immediately!
    EmailToken.confirm(Fabricate(:email_token, user: user).token)
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

  def start_code_login(email)
    visit("/login")
    expect(page).to have_css("#login-account-name")
    screenshot_marker(label: "code-login-password-form")

    find("#one-time-code-link").click
    expect(page).to have_css(".code-login-form__email-step")
    screenshot_marker(label: "code-login-email-step")

    find(".code-login-form__email-step input[type='email']").fill_in(with: email)
    find(".code-login-form__continue").click
    expect(page).to have_css(".code-login-form__code-step")
    screenshot_marker(label: "code-login-code-step")
  end

  it "logs an existing user in without a password" do
    start_code_login(user.email)
    expect(page).to have_css(".code-login-form__resend[disabled]")

    fill_code(latest_emailed_code(user.email))

    expect(page).to have_css(".header-dropdown-toggle.current-user")
    expect(User.find_by_email(user.email)).to eq(user)
  end

  it "shows an error for a wrong code, then accepts the correct one" do
    start_code_login(user.email)
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

  context "when the user has a second factor" do
    fab!(:user_second_factor) { Fabricate(:user_second_factor_totp, user: user) }

    it "prompts for the second factor before logging in" do
      start_code_login(user.email)
      fill_code(latest_emailed_code(user.email))

      expect(page).to have_css(".code-login-form__second-factor-step")
      screenshot_marker(label: "code-login-second-factor")

      find(".second-factor-token-input").fill_in(with: ROTP::TOTP.new(user_second_factor.data).now)
      find(".code-login-form__second-factor-step .code-login-form__verify").click

      expect(page).to have_css(".header-dropdown-toggle.current-user")
    end
  end

  it "can switch to the code form and back to password login" do
    visit("/login")
    expect(page).to have_css("#login-account-name")

    find("#one-time-code-link").click
    expect(page).to have_css(".code-login-form__email-step")

    find(".code-login-form__password-toggle").click
    expect(page).to have_css("#login-account-name")

    find("#login-account-name").fill_in(with: user.username)
    find("#login-account-password").fill_in(with: "supersecurepassword")
    find("#login-button").click

    expect(page).to have_css(".header-dropdown-toggle.current-user")
  end

  context "with a required checkbox user field" do
    fab!(:user_field) do
      Fabricate(:user_field, name: "Terms", field_type: "confirm", required: true)
    end

    it "renders the checkbox at a usable size and lets it be toggled" do
      new_email = "new.person@example.com"

      visit("/login")
      expect(page).to have_css("#login-account-name")
      find("#one-time-code-link").click
      expect(page).to have_css(".code-login-form__email-step")

      find(".code-login-form__email-step input[type='email']").fill_in(with: new_email)
      find(".code-login-form__continue").click
      expect(page).to have_css(".code-login-form__code-step")

      fill_code(latest_emailed_code(new_email))

      expect(page).to have_css(".code-login-form__user-fields-step")
      screenshot_marker(label: "code-login-user-fields-step")

      checkbox = find(".user-field.confirm input[type='checkbox']")

      # Regression: the shared `.input-group input` rule stretches inputs to
      # `min-width: 250px; width: 100%`. Without the checkbox override applying
      # to `.login-fullpage`, the checkbox renders as a full-width bar. Assert it
      # stays small.
      expect(checkbox.evaluate_script("this.offsetWidth")).to be < 50

      checkbox.click
      expect(checkbox).to be_checked

      find(".code-login-form__user-fields-step .code-login-form__verify").click

      expect(page).to have_css(".code-login-form__complete-step")

      user = User.find_by_email(new_email)
      expect(user.custom_fields["user_field_#{user_field.id}"]).to eq("true")
    end
  end

  context "when the setting is disabled" do
    before { SiteSetting.enable_local_logins_via_code = false }

    it "does not offer the code option" do
      visit("/login")

      expect(page).to have_css("#login-account-name")
      expect(page).to have_css("#email-login-link", visible: :all)
      expect(page).to have_no_css("#one-time-code-link", visible: :all)
    end
  end
end
