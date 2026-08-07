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

  def pick_username(name)
    fill_in("code-login-username", with: name)
    expect(page).to have_no_css(".code-login-form__continue-to-site[disabled]")
  end

  it "creates a passwordless account, picks a username, and logs in" do
    visit("/signup")
    expect(page).to have_css(".code-login-form__email-step")
    expect(page).to have_content(I18n.t("js.code_login.signup_title"))
    screenshot_marker(label: "code-signup-email-step")

    submit_email("new.person@example.com")
    screenshot_marker(label: "code-signup-code-step")

    fill_code(latest_emailed_code("new.person@example.com"))

    expect(page).to have_css(".code-login-form__complete-step")
    screenshot_marker(label: "code-signup-complete-step")

    # A username must be picked before the account can be used.
    expect(page).to have_css(".code-login-form__continue-to-site[disabled]")
    pick_username("new-person")

    find(".code-login-form__continue-to-site").click

    expect(page).to have_css(".header-dropdown-toggle.current-user")

    user = User.find_by_email("new.person@example.com")
    expect(user).to be_active
    expect(user.username).to eq("new-person")
    expect(user.user_password).to be_nil
  end

  it "shows a single heading that is replaced as the flow advances" do
    visit("/signup")

    expect(page).to have_css(".code-login-form__email-step")
    expect(page).to have_css(".login-welcome-header", count: 1)
    expect(page).to have_css(".login-title", text: I18n.t("js.code_login.signup_title"))
    expect(page).to have_no_css(".login-subheader")
    expect(page).to have_no_css(".code-login-form__title")
    expect(page).to have_css(
      ".code-login-form__instructions",
      text: I18n.t("js.code_login.signup_instructions"),
    )

    submit_email("new.person@example.com")

    expect(page).to have_css(".code-login-form__code-step")
    expect(page).to have_css(".login-welcome-header", count: 1)
    expect(page).to have_css(".login-title", text: I18n.t("js.code_login.check_your_email"))
    expect(page).to have_no_css(".code-login-form__title")

    fill_code(latest_emailed_code("new.person@example.com"))

    expect(page).to have_css(".code-login-form__complete-step")
    expect(page).to have_css(".login-welcome-header", count: 1)
    expect(page).to have_css(".login-title", text: I18n.t("js.code_login.account_ready_title"))
    expect(page).to have_no_css(".code-login-form__title")
  end

  it "blocks continuing while the picked username is taken" do
    Fabricate(:user, username: "takenname")

    visit("/signup")
    submit_email("new.person@example.com")
    fill_code(latest_emailed_code("new.person@example.com"))

    expect(page).to have_css(".code-login-form__complete-step")

    fill_in("code-login-username", with: "takenname")
    expect(page).to have_css(".code-login-form__error", text: "username")
    expect(page).to have_css(".code-login-form__continue-to-site[disabled]")
  end

  it "prefills the username when email-based suggestions are enabled" do
    SiteSetting.use_email_for_username_and_name_suggestions = true

    visit("/signup")
    submit_email("jane@example.com")
    fill_code(latest_emailed_code("jane@example.com"))

    expect(page).to have_css(".code-login-form__complete-step")
    expect(find("#code-login-username").value).to eq("jane")
  end

  it "keeps the generated username when usernames can't be changed" do
    SiteSetting.username_change_period = 0

    visit("/signup")
    submit_email("locked.name@example.com")
    fill_code(latest_emailed_code("locked.name@example.com"))

    expect(page).to have_css(".code-login-form__complete-step")
    expect(page).to have_no_css("#code-login-username")

    find(".code-login-form__continue-to-site").click
    expect(page).to have_css(".header-dropdown-toggle.current-user")
    expect(User.find_by_email("locked.name@example.com")).to be_present
  end

  it "opens the avatar picker before continuing" do
    visit("/signup")
    submit_email("avatar.person@example.com")
    fill_code(latest_emailed_code("avatar.person@example.com"))

    expect(page).to have_css(".code-login-form__complete-step")
    find(".code-login-form__avatar").click

    expect(page).to have_css(".avatar-selector-modal")
  end

  it "shows an error for an incorrect code" do
    visit("/signup")
    submit_email("new.person@example.com")

    correct_code = latest_emailed_code("new.person@example.com")
    fill_code(correct_code == "000000" ? "000001" : "000000")

    expect(page).to have_css(
      ".code-login-form__error",
      text: I18n.t("email_login_code.invalid_code"),
    )
    expect(page).to have_no_css(".header-dropdown-toggle.current-user")
    expect(User.find_by_email("new.person@example.com")).to be_nil
  end

  it "does not create an account when registrations are disabled" do
    SiteSetting.allow_new_registrations = false

    visit("/signup")
    submit_email("new.person@example.com")

    # No code is sent when registrations are closed, so any code is rejected.
    fill_code("000000")

    expect(page).to have_css(".code-login-form__error")
    expect(page).to have_no_css(".header-dropdown-toggle.current-user")
    expect(User.find_by_email("new.person@example.com")).to be_nil
  end

  it "shows a pending-approval message when users must be approved" do
    SiteSetting.must_approve_users = true

    visit("/signup")
    submit_email("approve.me@example.com")
    fill_code(latest_emailed_code("approve.me@example.com"))

    expect(page).to have_css(".code-login-form__error", text: I18n.t("login.not_approved"))
    expect(page).to have_no_css(".header-dropdown-toggle.current-user")

    user = User.find_by_email("approve.me@example.com")
    expect(user).not_to be_approved
    expect(ReviewableUser.pending.find_by(target: user)).to be_present
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
      pick_username("fields-person")
      find(".code-login-form__continue-to-site").click

      expect(page).to have_css(".header-dropdown-toggle.current-user")

      user = User.find_by_email("fields.person@example.com")
      expect(user.username).to eq("fields-person")
      expect(user.custom_fields["user_field_#{user_field.id}"]).to eq("Dev")
    end
  end

  context "when a full name is required at signup" do
    before { SiteSetting.full_name_requirement = "required_at_signup" }

    it "collects the name after the code is verified" do
      visit("/signup")
      submit_email("named.person@example.com")
      fill_code(latest_emailed_code("named.person@example.com"))

      expect(page).to have_css(".code-login-form__user-fields-step")
      expect(page).to have_css("#code-login-name")

      find(".code-login-form__user-fields-step .code-login-form__verify").click
      expect(page).to have_css(
        ".code-login-form__name-field .code-login-form__error",
        text: I18n.t("js.user.name.required"),
      )
      expect(page).to have_css(".code-login-form__user-fields-step")

      fill_in("code-login-name", with: "Jane Doe")
      find(".code-login-form__user-fields-step .code-login-form__verify").click

      expect(page).to have_css(".code-login-form__complete-step")
      expect(User.find_by_email("named.person@example.com").name).to eq("Jane Doe")
    end
  end
end
