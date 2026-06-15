# frozen_string_literal: true

describe "Sign up via email code" do
  include ThemeScreenshotMarker

  before do
    SiteSetting.enable_local_logins_via_email = true
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

  def submit_email(email)
    find(".code-login-form__email-step input[type='email']").fill_in(with: email)
    find(".code-login-form__continue").click
    expect(page).to have_css(".code-login-form__code-step")
  end

  it "creates a passwordless account and logs in" do
    visit("/signup")
    expect(page).to have_css(".code-login-form__email-step")
    expect(page).to have_content(I18n.t("js.code_login.signup_title"))
    screenshot_marker(label: "code-signup-email-step")

    submit_email("new.person@example.com")
    screenshot_marker(label: "code-signup-code-step")

    fill_code(latest_emailed_code("new.person@example.com"))

    user = User.find_by_email("new.person@example.com")
    expect(page).to have_css(".code-login-form__complete-step")
    expect(page).to have_css(".code-login-form__new-account-username", text: user.username)
    screenshot_marker(label: "code-signup-complete-step")

    find(".code-login-form__continue-to-site").click

    expect(page).to have_css(".header-dropdown-toggle.current-user")
    expect(user.reload).to be_active
    expect(user.user_password).to be_nil
  end

  context "with required user fields" do
    fab!(:user_field) { Fabricate(:user_field, name: "Occupation") }

    it "collects the fields after the code is verified" do
      visit("/signup")
      submit_email("fields.person@example.com")
      fill_code(latest_emailed_code("fields.person@example.com"))

      expect(page).to have_css(".code-login-form__user-fields-step")
      screenshot_marker(label: "code-signup-user-fields-step")

      find(".user-field-occupation input").fill_in(with: "Dev")
      find(".code-login-form__user-fields-step .code-login-form__verify").click

      expect(page).to have_css(".code-login-form__complete-step")
      find(".code-login-form__continue-to-site").click

      expect(page).to have_css(".header-dropdown-toggle.current-user")

      user = User.find_by_email("fields.person@example.com")
      expect(user.custom_fields["user_field_#{user_field.id}"]).to eq("Dev")
    end
  end
end
