# frozen_string_literal: true

describe "Sign up via email code" do
  include ThemeScreenshotMarker

  before do
    SiteSetting.enable_local_logins_via_email = true
    SiteSetting.enable_local_logins_via_code = true
    Jobs.run_immediately!
  end

  def open_code_signup
    browser_page.goto("/signup").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(
      browser_root.locator(".code-login-form__email-step").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    expect(
      browser_root.locator("#new-account-password").filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)
  end

  def fill_code(code)
    browser_root.locator(".d-otp-input").filter(visible: true).fill(code)
  end

  def latest_emailed_code(email)
    wait_for(timeout: 10) { ActionMailer::Base.deliveries.count != 0 }
    mail = ActionMailer::Base.deliveries.last
    expect(mail.to).to contain_exactly(email)
    mail.subject[/(\d{6})/, 1]
  end

  def submit_email(email)
    browser_root
      .locator(".code-login-form__email-step input[type='email']")
      .filter(visible: true)
      .fill(email)
    browser_root.locator(".code-login-form__continue").filter(visible: true).click
    expect(
      browser_root.locator(".code-login-form__code-step").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
  end

  def pick_username(name)
    browser_root
      .locator("input:not(:disabled), textarea:not(:disabled), select:not(:disabled)")
      .and(
        browser_root.locator(
          "[id=#{"code-login-username".to_s.to_json}], [name=#{"code-login-username".to_s.to_json}]",
        ).or(browser_root.get_by_label("code-login-username", exact: true)),
      )
      .filter(visible: true)
      .fill(name)
    expect(
      browser_root.locator(".code-login-form__continue-to-site[disabled]").filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)
  end

  it "creates a passwordless account, picks a username, and logs in" do
    SiteSetting.enable_random_usernames = true

    open_code_signup
    expect(
      browser_root.locator(".code-login-form__email-step").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    expect(browser_content).to PlaywrightMatchers.contain_text(
      browser_text_pattern(I18n.t("js.code_login.signup_title")),
      useInnerText: true,
    )
    screenshot_marker(label: "code-signup-email-step")

    submit_email("new.person@example.com")
    screenshot_marker(label: "code-signup-code-step")

    fill_code(latest_emailed_code("new.person@example.com"))

    expect(
      browser_root.locator(".code-login-form__signup-details-step").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    screenshot_marker(label: "code-signup-complete-step")

    generated = browser_root.locator("#code-login-username").filter(visible: true).input_value
    expect(generated).to match(/\A[A-Z][a-z]+[A-Z][a-z]+\d+\z/)
    expect(
      browser_root.locator(".code-login-form__continue-to-site[disabled]").filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)

    browser_root.locator(".code-login-form__username-regen").filter(visible: true).click
    expect(
      browser_root
        .locator("input:not(:disabled), textarea:not(:disabled), select:not(:disabled)")
        .and(
          browser_root.locator(
            "[id=#{"code-login-username".to_s.to_json}], [name=#{"code-login-username".to_s.to_json}]",
          ).or(browser_root.get_by_label("code-login-username", exact: true)),
        )
        .filter(visible: true),
    ).not_to PlaywrightMatchers.have_value(generated)

    pick_username("new-person")

    browser_root.locator(".code-login-form__continue-to-site").filter(visible: true).click

    expect(
      browser_root.locator(".header-dropdown-toggle.current-user").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)

    user = User.find_by_email("new.person@example.com")
    expect(user).to be_active
    expect(user.username).to eq("new-person")
    expect(user.user_password).to be_nil
  end

  it "shows a single heading that is replaced as the flow advances" do
    open_code_signup

    expect(
      browser_root.locator(".code-login-form__email-step").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    expect(
      browser_root.locator(".login-welcome-header").filter(visible: true),
    ).to PlaywrightMatchers.have_count(1)
    expect(
      browser_root.locator(".login-title").filter(visible: true),
    ).to PlaywrightMatchers.contain_text(
      [browser_text_pattern(I18n.t("js.code_login.signup_title"))],
      useInnerText: true,
    )
    expect(
      browser_root.locator(".login-subheader").filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)
    expect(
      browser_root.locator(".code-login-form__title").filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)
    expect(
      browser_root.locator(".code-login-form__instructions").filter(visible: true),
    ).to PlaywrightMatchers.contain_text(
      [browser_text_pattern(I18n.t("js.code_login.signup_instructions"))],
      useInnerText: true,
    )

    submit_email("new.person@example.com")

    expect(
      browser_root.locator(".code-login-form__code-step").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    expect(
      browser_root.locator(".login-welcome-header").filter(visible: true),
    ).to PlaywrightMatchers.have_count(1)
    expect(
      browser_root.locator(".login-title").filter(visible: true),
    ).to PlaywrightMatchers.contain_text(
      [browser_text_pattern(I18n.t("js.code_login.check_your_email"))],
      useInnerText: true,
    )
    expect(
      browser_root.locator(".code-login-form__title").filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)

    fill_code(latest_emailed_code("new.person@example.com"))

    expect(
      browser_root.locator(".code-login-form__signup-details-step").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    expect(
      browser_root.locator(".login-welcome-header").filter(visible: true),
    ).to PlaywrightMatchers.have_count(1)
    expect(
      browser_root.locator(".login-title").filter(visible: true),
    ).to PlaywrightMatchers.contain_text(
      [browser_text_pattern(I18n.t("js.code_login.signup_details_title"))],
      useInnerText: true,
    )
    expect(
      browser_root.locator(".code-login-form__title").filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)
  end

  it "blocks continuing while the picked username is taken" do
    Fabricate(:user, username: "takenname")

    open_code_signup
    submit_email("new.person@example.com")
    fill_code(latest_emailed_code("new.person@example.com"))

    expect(
      browser_root.locator(".code-login-form__signup-details-step").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)

    browser_root
      .locator("input:not(:disabled), textarea:not(:disabled), select:not(:disabled)")
      .and(
        browser_root.locator(
          "[id=#{"code-login-username".to_s.to_json}], [name=#{"code-login-username".to_s.to_json}]",
        ).or(browser_root.get_by_label("code-login-username", exact: true)),
      )
      .filter(visible: true)
      .fill("takenname")
    expect(
      browser_root.locator(".code-login-form__error").filter(visible: true),
    ).to PlaywrightMatchers.contain_text([browser_text_pattern("username")], useInnerText: true)
    expect(
      browser_root.locator(".code-login-form__continue-to-site[disabled]").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
  end

  it "prefills the username when email-based suggestions are enabled" do
    SiteSetting.use_email_for_username_and_name_suggestions = true

    open_code_signup
    submit_email("jane@example.com")
    fill_code(latest_emailed_code("jane@example.com"))

    expect(
      browser_root.locator(".code-login-form__signup-details-step").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    expect(browser_root.locator("#code-login-username").filter(visible: true).input_value).to eq(
      "jane",
    )
  end

  it "makes the user pick a username by default" do
    SiteSetting.use_email_for_username_and_name_suggestions = false

    open_code_signup
    submit_email("no.random@example.com")
    fill_code(latest_emailed_code("no.random@example.com"))

    expect(
      browser_root.locator(".code-login-form__signup-details-step").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    expect(
      browser_root.locator(".code-login-form__username-regen").filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)
    expect(browser_root.locator("#code-login-username").filter(visible: true).input_value).to eq("")
    expect(
      browser_root.locator(".code-login-form__continue-to-site[disabled]").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    expect(
      browser_root.locator(".code-login-form__avatar .d-icon-user").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    expect(
      browser_root.locator(".code-login-form__avatar img").filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)
    screenshot_marker(label: "deferred-signup-neutral-avatar")

    pick_username("no-random")
    expect(
      browser_root.locator(".code-login-form__avatar img").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    expect(
      browser_root.locator(".code-login-form__avatar .d-icon-user").filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)
    browser_root.locator(".code-login-form__continue-to-site").filter(visible: true).click

    expect(
      browser_root.locator(".header-dropdown-toggle.current-user").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    expect(User.find_by_email("no.random@example.com").username).to eq("no-random")
  end

  it "lets the user choose their initial username when later changes are disabled" do
    SiteSetting.username_change_period = 0

    open_code_signup
    submit_email("locked.name@example.com")
    fill_code(latest_emailed_code("locked.name@example.com"))

    expect(
      browser_root.locator(".code-login-form__signup-details-step").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    pick_username("locked-name")

    browser_root.locator(".code-login-form__continue-to-site").filter(visible: true).click
    expect(
      browser_root.locator(".header-dropdown-toggle.current-user").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    expect(User.find_by_email("locked.name@example.com").username).to eq("locked-name")
  end

  it "stays logged out when the user leaves without choosing a username" do
    open_code_signup
    submit_email("abandoned.person@example.com")
    fill_code(latest_emailed_code("abandoned.person@example.com"))

    expect(
      browser_root.locator(".code-login-form__signup-details-step").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    expect(
      browser_root.locator(".code-login-form__continue-to-site[disabled]").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)

    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(
      browser_root.locator(".header-dropdown-toggle.current-user").filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)
    expect(
      browser_root.locator(".login-button").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
  end

  it "previews a chosen avatar and applies it after creating the account" do
    User.set_callback(:create, :after, :ensure_in_trust_level_group)

    open_code_signup
    submit_email("avatar.person@example.com")
    fill_code(latest_emailed_code("avatar.person@example.com"))

    expect(
      browser_root.locator(".code-login-form__signup-details-step").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    browser_root.locator(".code-login-form__avatar").filter(visible: true).click
    browser_root.locator(
      "input[type='file']:not(:disabled)[id=#{"deferred-avatar-upload".to_s.to_json}], input[type='file']:not(:disabled)[name=#{"deferred-avatar-upload".to_s.to_json}]",
    ).set_input_files(File.absolute_path(file_from_fixtures("logo.jpg")))

    expect(
      browser_root.locator(".avatar-choice--upload img[src^='blob:']").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    screenshot_marker(label: "deferred-signup-avatar-picker")
    browser_root.locator(".avatar-selector-modal .btn-primary").filter(visible: true).click

    expect(
      browser_root.locator(".code-login-form__avatar img[src^='blob:']").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    pick_username("avatar-person")
    screenshot_marker(label: "deferred-signup-avatar-preview")
    browser_root.locator(".code-login-form__continue-to-site").filter(visible: true).click

    expect(
      browser_root.locator(".header-dropdown-toggle.current-user img[src*='/user_avatar/']").filter(
        visible: true,
      ),
    ).not_to PlaywrightMatchers.have_count(0)
  ensure
    User.skip_callback(:create, :after, :ensure_in_trust_level_group)
  end

  it "shows an error for an incorrect code" do
    open_code_signup
    submit_email("new.person@example.com")

    correct_code = latest_emailed_code("new.person@example.com")
    fill_code(correct_code == "000000" ? "000001" : "000000")

    expect(
      browser_root.locator(".code-login-form__error").filter(visible: true),
    ).to PlaywrightMatchers.contain_text(
      [browser_text_pattern(I18n.t("email_login_code.invalid_code"))],
      useInnerText: true,
    )
    expect(
      browser_root.locator(".header-dropdown-toggle.current-user").filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)
    expect(User.find_by_email("new.person@example.com")).to be_nil
  end

  it "does not create an account when registrations are disabled" do
    SiteSetting.allow_new_registrations = false

    open_code_signup
    submit_email("new.person@example.com")

    # No code is sent when registrations are closed, so any code is rejected.
    fill_code("000000")

    expect(
      browser_root.locator(".code-login-form__error").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    expect(
      browser_root.locator(".header-dropdown-toggle.current-user").filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)
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

    expect(
      browser_root.locator(".login-title").filter(visible: true),
    ).to PlaywrightMatchers.contain_text(
      [browser_text_pattern(I18n.t("js.code_login.account_details_title"))],
      useInnerText: true,
    )
    expect(
      browser_root.locator(".code-login-form__account-details-step").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    expect(User.find_by_email(email)).to be_nil

    generated_username =
      browser_root.locator("#code-login-username").filter(visible: true).input_value
    browser_root.locator(".code-login-form__username-regen").filter(visible: true).click
    expect(
      browser_root
        .locator("input:not(:disabled), textarea:not(:disabled), select:not(:disabled)")
        .and(
          browser_root.locator(
            "[id=#{"code-login-username".to_s.to_json}], [name=#{"code-login-username".to_s.to_json}]",
          ).or(browser_root.get_by_label("code-login-username", exact: true)),
        )
        .filter(visible: true),
    ).not_to PlaywrightMatchers.have_value(generated_username)
    expect(
      browser_root.locator(".dialog-container").filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)
    expect(User.find_by_email(email)).to be_nil
    rolled_username = browser_root.locator("#code-login-username").filter(visible: true).input_value
    expect(
      browser_root.locator(".code-login-form__submit-approval[disabled]").filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)

    with_logs do |browser_logs|
      browser_page.reload.tap { SystemBrowserBootstrap.wait_for(browser_page) }

      expect(browser_page).to PlaywrightMatchers.have_url("/signup")
      expect(
        browser_root.locator(".code-login-form__account-details-step").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
      expect(
        browser_root
          .locator("input:not(:disabled), textarea:not(:disabled), select:not(:disabled)")
          .and(
            browser_root.locator(
              "[id=#{"code-login-username".to_s.to_json}], [name=#{"code-login-username".to_s.to_json}]",
            ).or(browser_root.get_by_label("code-login-username", exact: true)),
          )
          .filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
      expect(User.find_by_email(email)).to be_nil

      browser_errors =
        browser_logs.logs.select do |log|
          log[:level] == "error" && !log[:message].include?("Failed to load resource")
        end
      expect(browser_errors).to be_empty
    end

    browser_root
      .locator("input:not(:disabled), textarea:not(:disabled), select:not(:disabled)")
      .and(
        browser_root.locator(
          "[id=#{"code-login-username".to_s.to_json}], [name=#{"code-login-username".to_s.to_json}]",
        ).or(browser_root.get_by_label("code-login-username", exact: true)),
      )
      .filter(visible: true)
      .fill("invalid username!")
    expect(
      browser_root.locator(".code-login-form__submit-approval[disabled]").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    expect(User.find_by_email(email)).to be_nil

    pick_username(rolled_username)
    browser_root.locator(".code-login-form__submit-approval").filter(visible: true).click

    expect(
      browser_root.locator(".code-login-form__name-field .code-login-form__error").filter(
        visible: true,
      ),
    ).to PlaywrightMatchers.contain_text(
      [browser_text_pattern(I18n.t("js.user.name.required"))],
      useInnerText: true,
    )
    expect(User.find_by_email(email)).to be_nil

    browser_root
      .locator("input:not(:disabled), textarea:not(:disabled), select:not(:disabled)")
      .and(
        browser_root.locator(
          "[id=#{"code-login-name".to_s.to_json}], [name=#{"code-login-name".to_s.to_json}]",
        ).or(browser_root.get_by_label("code-login-name", exact: true)),
      )
      .filter(visible: true)
      .fill("Chosen Name")
    browser_root.locator(".user-field-occupation input").filter(visible: true).fill("Engineer")
    browser_root.locator(".code-login-form__submit-approval").filter(visible: true).click

    expect(
      browser_root.locator(".login-title").filter(visible: true),
    ).to PlaywrightMatchers.contain_text(
      [browser_text_pattern(I18n.t("js.code_login.pending_approval_title"))],
      useInnerText: true,
    )
    expect(
      browser_root.locator(".login-subheader").filter(visible: true),
    ).to PlaywrightMatchers.contain_text(
      [browser_text_pattern(I18n.t("js.code_login.pending_approval_instructions"))],
      useInnerText: true,
    )
    expect(
      browser_root.locator(".d-otp-input").filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)
    expect(
      browser_root.locator(".header-dropdown-toggle.current-user").filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)

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
    expect(browser_content).to PlaywrightMatchers.contain_text(
      browser_text_pattern(rolled_username),
      useInnerText: true,
    )
    expect(browser_content).to PlaywrightMatchers.contain_text(
      browser_text_pattern("Chosen Name"),
      useInnerText: true,
    )
    expect(browser_content).to PlaywrightMatchers.contain_text(
      browser_text_pattern("Occupation"),
      useInnerText: true,
    )
    expect(browser_content).to PlaywrightMatchers.contain_text(
      browser_text_pattern("Engineer"),
      useInnerText: true,
    )
    review_page.click_approve_user_button

    expect(review_page).to have_reviewable_with_approved_status(reviewable)
    expect(user.reload).to be_approved
    approval_email = ActionMailer::Base.deliveries.last
    expect(approval_email.to).to contain_exactly(email)
    expect(approval_email.body.to_s).to include("/login?mode=code")

    user_menu = PageObjects::Components::UserMenu.new
    user_menu.open.click_profile_tab
    browser_root.locator("#quick-access-profile .logout .btn").filter(visible: true).click
    expect(browser_page).to PlaywrightMatchers.have_url("/")
    browser_page.goto("/login?mode=code").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    submit_email(email)
    fill_code(latest_emailed_code(email))

    expect(
      browser_root.locator(".header-dropdown-toggle.current-user").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
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

    expect(
      browser_root
        .get_by_role("button")
        .and(
          browser_root.locator(
            "[id=#{I18n.t("js.code_login.create_password_optional").to_s.to_json}], [name=#{I18n.t("js.code_login.create_password_optional").to_s.to_json}]",
          ).or(
            browser_root.get_by_role(
              "button",
              name: I18n.t("js.code_login.create_password_optional"),
            ),
          ),
        )
        .filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    expect(
      browser_root.locator(".code-login-form__create-password.btn-link").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    expect(
      browser_root
        .get_by_role("button")
        .and(
          browser_root.locator(
            "[id=#{I18n.t("js.code_login.use_different_email").to_s.to_json}], [name=#{I18n.t("js.code_login.use_different_email").to_s.to_json}]",
          ).or(
            browser_root.get_by_role("button", name: I18n.t("js.code_login.use_different_email")),
          ),
        )
        .filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)
    expect(
      browser_root
        .locator("input:not(:disabled), textarea:not(:disabled), select:not(:disabled)")
        .and(
          browser_root.locator(
            "[id=#{"new-account-password".to_s.to_json}], [name=#{"new-account-password".to_s.to_json}]",
          ).or(browser_root.get_by_label("new-account-password", exact: true)),
        )
        .filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)
    screenshot_marker(label: "code-signup-account-details-password-link")

    browser_root.locator(".code-login-form__create-password").filter(visible: true).click
    expect(
      browser_root
        .locator("input:not(:disabled), textarea:not(:disabled), select:not(:disabled)")
        .and(
          browser_root.locator(
            "[id=#{"new-account-password".to_s.to_json}], [name=#{"new-account-password".to_s.to_json}]",
          ).or(browser_root.get_by_label("new-account-password", exact: true)),
        )
        .and(browser_root.locator("[type=#{"password".to_s.to_json}]"))
        .filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    screenshot_marker(label: "code-signup-account-details-password-expanded")

    pick_username("password-approval")

    browser_root
      .locator("input:not(:disabled), textarea:not(:disabled), select:not(:disabled)")
      .and(
        browser_root.locator(
          "[id=#{"new-account-password".to_s.to_json}], [name=#{"new-account-password".to_s.to_json}]",
        ).or(browser_root.get_by_label("new-account-password", exact: true)),
      )
      .filter(visible: true)
      .fill("short")
    expect(
      browser_root.locator(".code-login-form__submit-approval[disabled]").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)

    browser_root
      .locator("input:not(:disabled), textarea:not(:disabled), select:not(:disabled)")
      .and(
        browser_root.locator(
          "[id=#{"new-account-password".to_s.to_json}], [name=#{"new-account-password".to_s.to_json}]",
        ).or(browser_root.get_by_label("new-account-password", exact: true)),
      )
      .filter(visible: true)
      .fill(password)
    expect(
      browser_root.locator(".code-login-form__submit-approval[disabled]").filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)
    browser_root.locator(".code-login-form__submit-approval").filter(visible: true).click

    expect(
      browser_root.locator(".code-login-form__pending-approval-step"),
    ).to PlaywrightMatchers.be_attached
    expect(browser_root.locator(".login-title")).to PlaywrightMatchers.contain_text(
      I18n.t("js.code_login.pending_approval_title"),
      useInnerText: true,
    )
    expect(
      browser_root.locator(".header-dropdown-toggle.current-user").filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)
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
    browser_root.locator("#quick-access-profile .logout .btn").filter(visible: true).click
    expect(browser_page).to PlaywrightMatchers.have_url("/")

    browser_page.goto("/login").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(
      browser_root
        .locator("input:not(:disabled), textarea:not(:disabled), select:not(:disabled)")
        .and(
          browser_root.locator(
            "[id=#{"login-account-password".to_s.to_json}], [name=#{"login-account-password".to_s.to_json}]",
          ).or(browser_root.get_by_label("login-account-password", exact: true)),
        )
        .filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    browser_root
      .locator("input:not(:disabled), textarea:not(:disabled), select:not(:disabled)")
      .and(
        browser_root.locator(
          "[id=#{"login-account-name".to_s.to_json}], [name=#{"login-account-name".to_s.to_json}]",
        ).or(browser_root.get_by_label("login-account-name", exact: true)),
      )
      .filter(visible: true)
      .fill(email)
    browser_root
      .locator("input:not(:disabled), textarea:not(:disabled), select:not(:disabled)")
      .and(
        browser_root.locator(
          "[id=#{"login-account-password".to_s.to_json}], [name=#{"login-account-password".to_s.to_json}]",
        ).or(browser_root.get_by_label("login-account-password", exact: true)),
      )
      .filter(visible: true)
      .fill(password)
    browser_root.locator("#login-button").filter(visible: true).click

    expect(
      browser_root.locator(".header-dropdown-toggle.current-user").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
  end

  context "with required user fields" do
    fab!(:user_field) { Fabricate(:user_field, name: "Occupation") }

    it "collects the fields after the code is verified" do
      open_code_signup
      submit_email("fields.person@example.com")
      fill_code(latest_emailed_code("fields.person@example.com"))

      expect(
        browser_root.locator(".code-login-form__user-fields-step").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
      screenshot_marker(label: "code-signup-user-fields-step")

      browser_root.locator(".user-field-occupation input").filter(visible: true).fill("Dev")
      browser_root
        .locator(".code-login-form__user-fields-step .code-login-form__verify")
        .filter(visible: true)
        .click

      expect(
        browser_root.locator(".code-login-form__signup-details-step").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
      pick_username("fields-person")
      browser_root.locator(".code-login-form__continue-to-site").filter(visible: true).click

      expect(
        browser_root.locator(".header-dropdown-toggle.current-user").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)

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

      expect(
        browser_root.locator(".code-login-form__user-fields-step").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
      expect(
        browser_root.locator("#code-login-name").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)

      browser_root
        .locator(".code-login-form__user-fields-step .code-login-form__verify")
        .filter(visible: true)
        .click
      expect(
        browser_root.locator(".code-login-form__name-field .code-login-form__error").filter(
          visible: true,
        ),
      ).to PlaywrightMatchers.contain_text(
        [browser_text_pattern(I18n.t("js.user.name.required"))],
        useInnerText: true,
      )
      expect(
        browser_root.locator(".code-login-form__user-fields-step").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)

      browser_root
        .locator("input:not(:disabled), textarea:not(:disabled), select:not(:disabled)")
        .and(
          browser_root.locator(
            "[id=#{"code-login-name".to_s.to_json}], [name=#{"code-login-name".to_s.to_json}]",
          ).or(browser_root.get_by_label("code-login-name", exact: true)),
        )
        .filter(visible: true)
        .fill("Jane Doe")
      browser_root
        .locator(".code-login-form__user-fields-step .code-login-form__verify")
        .filter(visible: true)
        .click

      expect(
        browser_root.locator(".code-login-form__signup-details-step").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
      pick_username("named-person")
      browser_root.locator(".code-login-form__continue-to-site").filter(visible: true).click

      expect(
        browser_root.locator(".header-dropdown-toggle.current-user").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
      expect(User.find_by_email("named.person@example.com").name).to eq("Jane Doe")
    end
  end
end
