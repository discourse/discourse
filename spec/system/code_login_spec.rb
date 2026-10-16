# frozen_string_literal: true

require "rotp"

describe "Login via email code", native_playwright: true do
  include ThemeScreenshotMarker

  fab!(:user) { Fabricate(:user, password: "supersecurepassword") }

  let(:login) { PageObjects::Native::Login.new(browser_page) }

  before do
    SiteSetting.enable_local_logins_via_email = true
    SiteSetting.enable_local_logins_via_code = true
    Jobs.run_immediately!
    EmailToken.confirm(Fabricate(:email_token, user: user).token)
  end

  def fill_code(code)
    login.code_input.fill(code)
  end

  def latest_emailed_code(email)
    wait_for(timeout: 10) { ActionMailer::Base.deliveries.count != 0 }
    mail = ActionMailer::Base.deliveries.last
    expect(mail.to).to contain_exactly(email)
    mail.subject[/(\d{6})/, 1]
  end

  def start_code_login(email)
    login.visit
    expect(login.account_name).to be_visible
    login.code_login_link.click
    expect(login.email_step).to be_visible
    screenshot_marker(label: "code-login-email-step")

    login.email_input.fill(email)
    login.continue_button.click
    expect(login.code_step).to be_visible
    screenshot_marker(label: "code-login-code-step")
  end

  it "logs an existing user in without a password" do
    start_code_login(user.email)
    expect(login.resend_button).to be_visible
    expect(login.resend_button).to be_disabled

    fill_code(latest_emailed_code(user.email))

    expect(login.current_user).to be_visible
    expect(User.find_by_email(user.email)).to eq(user)
  end

  it "shows an error for a wrong code, then accepts the correct one" do
    start_code_login(user.email)
    code = latest_emailed_code(user.email)
    wrong_code = code == "000000" ? "000001" : "000000"

    fill_code(wrong_code)
    expect(login.error).to contain_text(I18n.t("email_login_code.invalid_code"))
    screenshot_marker(label: "code-login-wrong-code")

    fill_code(code)
    expect(login.current_user).to be_visible
  end

  context "when the user has a second factor" do
    fab!(:user_second_factor) { Fabricate(:user_second_factor_totp, user: user) }

    it "prompts for the second factor before logging in" do
      start_code_login(user.email)
      fill_code(latest_emailed_code(user.email))

      expect(login.second_factor_step).to be_visible
      screenshot_marker(label: "code-login-second-factor")

      login.second_factor_input.fill(ROTP::TOTP.new(user_second_factor.data).now)
      login.second_factor_verify.click

      expect(login.current_user).to be_visible
    end
  end

  it "defaults to password login and can opt into code login" do
    login.visit
    expect(login.account_name).to be_visible
    expect(login.form).to have_count(0)
    screenshot_marker(label: "code-login-password-form")

    login.code_login_link.click
    expect(login.email_step).to be_visible
    login.password_toggle.click
    expect(login.account_name).to be_visible

    login.account_name.fill(user.username)
    login.account_password.fill("supersecurepassword")
    login.login_button.click

    expect(login.current_user).to be_visible
  end

  context "with a required checkbox user field" do
    fab!(:user_field) do
      Fabricate(:user_field, name: "Terms", field_type: "confirm", required: true)
    end

    it "renders the checkbox at a usable size and lets it be toggled" do
      new_email = "new.person@example.com"

      login.visit_code_login
      expect(login.email_step).to be_visible

      login.email_input.fill(new_email)
      login.continue_button.click
      expect(login.code_step).to be_visible

      fill_code(latest_emailed_code(new_email))

      expect(login.user_fields_step).to be_visible
      screenshot_marker(label: "code-login-user-fields-step")

      checkbox = login.terms_checkbox

      # Regression: the shared `.input-group input` rule stretches inputs to
      # `min-width: 250px; width: 100%`. Without the checkbox override applying
      # to `.login-fullpage`, the checkbox renders as a full-width bar. Assert it
      # stays small.
      expect(checkbox.evaluate("element => element.offsetWidth")).to be < 50

      checkbox.click
      expect(checkbox).to be_checked

      login.user_fields_verify.click

      expect(login.signup_details_step).to be_visible

      login.signup_username.fill("new-person")
      expect(login.continue_to_site).to be_enabled
      login.continue_to_site.click

      expect(login.current_user).to be_visible

      user = User.find_by_email(new_email)
      expect(user.custom_fields["user_field_#{user_field.id}"]).to eq("true")
    end
  end

  context "when the setting is disabled" do
    before { SiteSetting.enable_local_logins_via_code = false }

    it "does not offer the code option" do
      login.visit

      expect(login.account_name).to be_visible
      expect(login.email_login_link).to have_count(1)
      expect(login.code_login_link).to have_count(0)
    end
  end
end
