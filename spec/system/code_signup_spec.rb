# frozen_string_literal: true

describe "Sign up via email code" do
  include ThemeScreenshotMarker

  before do
    SiteSetting.enable_local_logins_via_email = true
    SiteSetting.enable_local_logins_via_code = true
    Jobs.run_immediately!
  end

  def open_code_signup
    visit("/signup")
    expect(page).to have_css(".code-login-form__email-step")
    expect(page).to have_no_css("#new-account-password")
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
    SiteSetting.enable_random_usernames = true

    open_code_signup
    expect(page).to have_css(".code-login-form__email-step")
    expect(page).to have_content(I18n.t("js.code_login.signup_title"))
    screenshot_marker(label: "code-signup-email-step")

    submit_email("new.person@example.com")
    screenshot_marker(label: "code-signup-code-step")

    fill_code(latest_emailed_code("new.person@example.com"))

    expect(page).to have_css(".code-login-form__complete-step")
    screenshot_marker(label: "code-signup-complete-step")

    generated = find("#code-login-username").value
    expect(generated).to match(/\A[A-Z][a-z]+[A-Z][a-z]+\d+\z/)
    expect(page).to have_no_css(".code-login-form__continue-to-site[disabled]")

    find(".code-login-form__username-regen").click
    expect(page).to have_no_field("code-login-username", with: generated)

    pick_username("new-person")

    find(".code-login-form__continue-to-site").click

    expect(page).to have_css(".header-dropdown-toggle.current-user")

    user = User.find_by_email("new.person@example.com")
    expect(user).to be_active
    expect(user.username).to eq("new-person")
    expect(user.user_password).to be_nil
  end

  it "shows a single heading that is replaced as the flow advances" do
    open_code_signup

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
    expect(page).to have_css(".login-title", text: I18n.t("js.code_login.signup_details_title"))
    expect(page).to have_no_css(".code-login-form__title")
  end

  it "blocks continuing while the picked username is taken" do
    Fabricate(:user, username: "takenname")

    open_code_signup
    submit_email("new.person@example.com")
    fill_code(latest_emailed_code("new.person@example.com"))

    expect(page).to have_css(".code-login-form__complete-step")

    fill_in("code-login-username", with: "takenname")
    expect(page).to have_css(".code-login-form__error", text: "username")
    expect(page).to have_css(".code-login-form__continue-to-site[disabled]")
  end

  it "prefills the username when email-based suggestions are enabled" do
    SiteSetting.use_email_for_username_and_name_suggestions = true

    open_code_signup
    submit_email("jane@example.com")
    fill_code(latest_emailed_code("jane@example.com"))

    expect(page).to have_css(".code-login-form__complete-step")
    expect(find("#code-login-username").value).to eq("jane")
  end

  it "makes the user pick a username by default" do
    SiteSetting.use_email_for_username_and_name_suggestions = false

    open_code_signup
    submit_email("no.random@example.com")
    fill_code(latest_emailed_code("no.random@example.com"))

    expect(page).to have_css(".code-login-form__complete-step")
    expect(page).to have_no_css(".code-login-form__username-regen")
    expect(find("#code-login-username").value).to eq("")
    expect(page).to have_css(".code-login-form__continue-to-site[disabled]")
    expect(page).to have_css(".code-login-form__avatar .d-icon-user")
    expect(page).to have_no_css(".code-login-form__avatar img")
    screenshot_marker(label: "deferred-signup-neutral-avatar")

    pick_username("no-random")
    expect(page).to have_css(".code-login-form__avatar img")
    expect(page).to have_no_css(".code-login-form__avatar .d-icon-user")
    find(".code-login-form__continue-to-site").click

    expect(page).to have_css(".header-dropdown-toggle.current-user")
    expect(User.find_by_email("no.random@example.com").username).to eq("no-random")
  end

  it "lets the user choose their initial username when later changes are disabled" do
    SiteSetting.username_change_period = 0

    open_code_signup
    submit_email("locked.name@example.com")
    fill_code(latest_emailed_code("locked.name@example.com"))

    expect(page).to have_css(".code-login-form__complete-step")
    pick_username("locked-name")

    find(".code-login-form__continue-to-site").click
    expect(page).to have_css(".header-dropdown-toggle.current-user")
    expect(User.find_by_email("locked.name@example.com").username).to eq("locked-name")
  end

  it "stays logged out when the user leaves without choosing a username" do
    open_code_signup
    submit_email("abandoned.person@example.com")
    fill_code(latest_emailed_code("abandoned.person@example.com"))

    expect(page).to have_css(".code-login-form__complete-step")
    expect(page).to have_css(".code-login-form__continue-to-site[disabled]")

    visit("/")

    expect(page).to have_no_css(".header-dropdown-toggle.current-user")
    expect(page).to have_css(".login-button")
  end

  it "previews a chosen avatar and applies it after creating the account" do
    User.set_callback(:create, :after, :ensure_in_trust_level_group)

    open_code_signup
    submit_email("avatar.person@example.com")
    fill_code(latest_emailed_code("avatar.person@example.com"))

    expect(page).to have_css(".code-login-form__complete-step")
    find(".code-login-form__avatar").click
    attach_file(
      "deferred-avatar-upload",
      File.absolute_path(file_from_fixtures("logo.jpg")),
      make_visible: true,
    )

    expect(page).to have_css(".avatar-choice--upload img[src^='blob:']")
    screenshot_marker(label: "deferred-signup-avatar-picker")
    find(".avatar-selector-modal .btn-primary").click

    expect(page).to have_css(".code-login-form__avatar img[src^='blob:']")
    pick_username("avatar-person")
    screenshot_marker(label: "deferred-signup-avatar-preview")
    find(".code-login-form__continue-to-site").click

    expect(page).to have_css(".header-dropdown-toggle.current-user img[src*='/user_avatar/']")
  ensure
    User.skip_callback(:create, :after, :ensure_in_trust_level_group)
  end

  it "shows an error for an incorrect code" do
    open_code_signup
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

    open_code_signup
    submit_email("new.person@example.com")

    # No code is sent when registrations are closed, so any code is rejected.
    fill_code("000000")

    expect(page).to have_css(".code-login-form__error")
    expect(page).to have_no_css(".header-dropdown-toggle.current-user")
    expect(User.find_by_email("new.person@example.com")).to be_nil
  end

  it "collects account details before approval and requires a fresh code afterward" do
    SiteSetting.enable_random_usernames = true
    SiteSetting.login_required = true
    SiteSetting.must_approve_users = true
    SiteSetting.full_name_requirement = "required_at_signup"
    user_field = Fabricate(:user_field, name: "Occupation")
    admin = Fabricate(:admin)
    email = "approve.me@example.com"

    open_code_signup
    submit_email(email)
    fill_code(latest_emailed_code(email))

    expect(page).to have_css(".login-title", text: I18n.t("js.code_login.account_details_title"))
    expect(page).to have_css(".code-login-form__account-details-step")
    expect(User.find_by_email(email)).to be_nil

    generated_username = find("#code-login-username").value
    find(".code-login-form__username-regen").click
    expect(page).to have_no_field("code-login-username", with: generated_username)
    expect(page).to have_no_css(".dialog-container")
    expect(User.find_by_email(email)).to be_nil
    rolled_username = find("#code-login-username").value
    expect(page).to have_no_css(".code-login-form__submit-approval[disabled]")

    with_logs do |browser_logs|
      page.refresh

      expect(page).to have_current_path("/signup")
      expect(page).to have_css(".code-login-form__account-details-step")
      expect(page).to have_field("code-login-username")
      expect(User.find_by_email(email)).to be_nil

      browser_errors =
        browser_logs.logs.select do |log|
          log[:level] == "error" && !log[:message].include?("Failed to load resource")
        end
      expect(browser_errors).to be_empty
    end

    fill_in("code-login-username", with: "invalid username!")
    expect(page).to have_css(".code-login-form__submit-approval[disabled]")
    expect(User.find_by_email(email)).to be_nil

    pick_username(rolled_username)
    find(".code-login-form__submit-approval").click

    expect(page).to have_css(
      ".code-login-form__name-field .code-login-form__error",
      text: I18n.t("js.user.name.required"),
    )
    expect(User.find_by_email(email)).to be_nil

    fill_in("code-login-name", with: "Chosen Name")
    find(".user-field-occupation input").fill_in(with: "Engineer")
    find(".code-login-form__submit-approval").click

    expect(page).to have_css(".login-title", text: I18n.t("js.code_login.pending_approval_title"))
    expect(page).to have_css(
      ".login-subheader",
      text: I18n.t("js.code_login.pending_approval_instructions"),
    )
    expect(page).to have_no_css(".d-otp-input")
    expect(page).to have_no_css(".header-dropdown-toggle.current-user")

    user = User.find_by_email(email)
    expect(user).not_to be_approved
    expect(user.username).to eq(rolled_username)
    expect(user.name).to eq("Chosen Name")
    expect(user.custom_fields["user_field_#{user_field.id}"]).to eq("Engineer")

    reviewable = ReviewableUser.pending.find_by!(target: user)
    expect(reviewable.payload.slice("username", "name")).to eq(
      "username" => rolled_username,
      "name" => "Chosen Name",
    )

    sign_in(admin)
    review_page = PageObjects::Pages::Review.new
    review_page.visit_reviewable(reviewable)
    expect(page).to have_content(rolled_username)
    expect(page).to have_content("Chosen Name")
    expect(page).to have_content("Occupation")
    expect(page).to have_content("Engineer")
    review_page.click_approve_user_button

    expect(review_page).to have_reviewable_with_approved_status(reviewable)
    expect(user.reload).to be_approved
    approval_email = ActionMailer::Base.deliveries.last
    expect(approval_email.to).to contain_exactly(email)
    expect(approval_email.body.to_s).to include("/login?mode=code")

    user_menu = PageObjects::Components::UserMenu.new
    user_menu.open.click_profile_tab
    find("#quick-access-profile .logout .btn").click
    expect(page).to have_current_path("/")
    visit("/login?mode=code")
    find(".code-login-form__email-step input[type='email']").fill_in(with: email)
    find(".code-login-form__continue").click
    fill_code(latest_emailed_code(email))

    expect(page).to have_css(".header-dropdown-toggle.current-user")
    expect(User.find_by_email(email).username).to eq(rolled_username)
  end

  it "creates a password account before approval and logs in with it after approval" do
    SiteSetting.must_approve_users = true
    admin = Fabricate(:admin)
    email = "password.approval@example.com"
    password = "a-secure-password-42!"

    open_code_signup
    submit_email(email)
    fill_code(latest_emailed_code(email))

    expect(page).to have_button(I18n.t("js.code_login.create_password_optional"))
    expect(page).to have_css(".code-login-form__create-password.btn-link")
    expect(page).to have_no_button(I18n.t("js.code_login.use_different_email"))
    expect(page).to have_no_field("new-account-password")
    screenshot_marker(label: "code-signup-account-details-password-link")

    find(".code-login-form__create-password").click
    expect(page).to have_field("new-account-password", type: "password")
    screenshot_marker(label: "code-signup-account-details-password-expanded")

    pick_username("password-approval")

    fill_in("new-account-password", with: "short")
    expect(page).to have_css(".code-login-form__submit-approval[disabled]")

    fill_in("new-account-password", with: password)
    expect(page).to have_no_css(".code-login-form__submit-approval[disabled]")
    find(".code-login-form__submit-approval").click

    expect(page).to have_css(".code-login-form__pending-approval-step")
    expect(page).to have_no_css(".header-dropdown-toggle.current-user")
    screenshot_marker(label: "code-signup-pending-approval")

    user = User.find_by_email(email)
    expect(user).not_to be_approved
    expect(user.confirm_password?(password)).to eq(true)

    reviewable = ReviewableUser.pending.find_by!(target: user)
    sign_in(admin)
    review_page = PageObjects::Pages::Review.new
    review_page.visit_reviewable(reviewable)
    review_page.click_approve_user_button

    expect(review_page).to have_reviewable_with_approved_status(reviewable)
    approval_email = ActionMailer::Base.deliveries.last
    expect(approval_email.body.to_s).to include("logging in at:")
    expect(approval_email.body.to_s).not_to include("request a fresh login code")

    user_menu = PageObjects::Components::UserMenu.new
    user_menu.open.click_profile_tab
    find("#quick-access-profile .logout .btn").click
    expect(page).to have_current_path("/")

    visit("/login")
    expect(page).to have_field("login-account-password")
    fill_in("login-account-name", with: email)
    fill_in("login-account-password", with: password)
    find("#login-button").click

    expect(page).to have_css(".header-dropdown-toggle.current-user")
  end

  context "with required user fields" do
    fab!(:user_field) { Fabricate(:user_field, name: "Occupation") }

    it "collects the fields after the code is verified" do
      open_code_signup
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
      open_code_signup
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
      pick_username("named-person")
      find(".code-login-form__continue-to-site").click

      expect(page).to have_css(".header-dropdown-toggle.current-user")
      expect(User.find_by_email("named.person@example.com").name).to eq("Jane Doe")
    end
  end
end
