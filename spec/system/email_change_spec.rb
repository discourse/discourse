# frozen_string_literal: true

describe "Changing email" do
  fab!(:password) { "mysupersecurepassword" }
  fab!(:user) { Fabricate(:user, active: true, password: password) }
  let(:new_email) { "newemail@example.com" }
  let(:user_preferences_security_page) { PageObjects::Pages::UserPreferencesSecurity.new }
  let(:user_preferences_page) { PageObjects::Pages::UserPreferences.new }

  before { Jobs.run_immediately! }

  def generate_confirm_link
    browser_page
      .goto("/my/preferences/account")
      .tap { SystemBrowserBootstrap.wait_for(browser_page) }

    email_dropdown = PageObjects::Components::SelectKit.new(".email-dropdown")
    expect(email_dropdown.visible?).to eq(true)
    email_dropdown.select_row_by_value("updateEmail")

    browser_root.locator("#change-email").filter(visible: true).fill("newemail@example.com")

    browser_root.locator(".save-button button").filter(visible: true).click

    wait_for(timeout: Capybara.default_max_wait_time * 2) do
      ActionMailer::Base.deliveries.count === 1
    end

    if user.admin?
      get_link_from_email(:old)
    else
      get_link_from_email(:new)
    end
  end

  def get_link_from_email(type)
    mail = ActionMailer::Base.deliveries.last
    expect(mail.to).to contain_exactly(type == :new ? new_email : user.email)

    mail.body.to_s[%r{/u/confirm-#{type}-email/\S+}, 0]
  end

  it "allows regular user to change their email" do
    sign_in user

    browser_page.goto(generate_confirm_link).tap { SystemBrowserBootstrap.wait_for(browser_page) }

    browser_root.locator(".confirm-new-email .btn-primary").filter(visible: true).click

    expect(
      browser_root.locator(".dialog-body").filter(visible: true),
    ).to PlaywrightMatchers.contain_text(
      [browser_text_pattern(I18n.t("js.user.change_email.confirm_success"))],
      useInnerText: true,
    )
    browser_root.locator(".dialog-footer .btn-primary").filter(visible: true).click

    expect(user.reload.primary_email.email).to eq(new_email)
  end

  it "works when user has totp 2fa", dump_threads_on_failure: true do
    SiteSetting.hide_email_address_taken = false

    second_factor = Fabricate(:user_second_factor_totp, user: user)
    sign_in user

    browser_page.goto(generate_confirm_link).tap { SystemBrowserBootstrap.wait_for(browser_page) }

    browser_root.locator(".confirm-new-email .btn-primary").filter(visible: true).click
    browser_root
      .locator(".second-factor-token-input")
      .filter(visible: true)
      .fill(second_factor.totp_object.now)
    browser_root.locator("button[type=submit]").filter(visible: true).click

    expect(user.reload.primary_email.email).to eq(new_email)
  end

  it "works when user has webauthn 2fa" do
    with_security_key(user) do
      sign_in user
      browser_page.goto(generate_confirm_link).tap { SystemBrowserBootstrap.wait_for(browser_page) }

      browser_root.locator(".confirm-new-email .btn-primary").filter(visible: true).click
      browser_root.locator("#security-key-authenticate-button").filter(visible: true).click

      try_until_success(
        reason: "Something about webauthn.js that we can't seem to track properly",
      ) { expect(user.reload.primary_email.email).to eq(new_email) }
    end
  end

  it "does not require login to confirm email change" do
    second_factor = Fabricate(:user_second_factor_totp, user: user)
    sign_in user

    confirm_link = generate_confirm_link

    reset_browser_sessions # log out

    browser_page.goto(confirm_link).tap { SystemBrowserBootstrap.wait_for(browser_page) }

    browser_root.locator(".confirm-new-email .btn-primary").filter(visible: true).click
    browser_root
      .locator(".second-factor-token-input")
      .filter(visible: true)
      .fill(second_factor.totp_object.now)
    browser_root.locator("button[type=submit]:not([disabled])").filter(visible: true).click

    expect(user.reload.primary_email.email).to eq(new_email)
  end

  it "makes admins verify old email" do
    user.update!(admin: true)
    sign_in user

    confirm_old_link = generate_confirm_link

    # Confirm old email
    browser_page.goto(confirm_old_link).tap { SystemBrowserBootstrap.wait_for(browser_page) }
    browser_root.locator(".confirm-old-email .btn-primary").filter(visible: true).click
    expect(
      browser_root.locator(".dialog-body").filter(visible: true),
    ).to PlaywrightMatchers.contain_text(
      [browser_text_pattern(I18n.t("js.user.change_email.authorizing_old.confirm_success"))],
      useInnerText: true,
    )
    browser_root.locator(".dialog-footer .btn-primary").filter(visible: true).click

    # Confirm new email
    wait_for(timeout: Capybara.default_max_wait_time * 2) do
      ActionMailer::Base.deliveries.count === 2
    end

    confirm_new_link = get_link_from_email(:new)

    browser_page.goto(confirm_new_link).tap { SystemBrowserBootstrap.wait_for(browser_page) }

    browser_root.locator(".confirm-new-email .btn-primary").filter(visible: true).click

    expect(
      browser_root.locator(".dialog-body").filter(visible: true),
    ).to PlaywrightMatchers.contain_text(
      [browser_text_pattern(I18n.t("js.user.change_email.confirm_success"))],
      useInnerText: true,
    )
    browser_root.locator(".dialog-footer .btn-primary").filter(visible: true).click

    expect(user.reload.primary_email.email).to eq(new_email)
  end

  it "allows admin to verify old email while logged out" do
    user.update!(admin: true)
    sign_in user

    confirm_old_link = generate_confirm_link

    reset_browser_sessions # log out

    # Confirm old email
    browser_page.goto(confirm_old_link).tap { SystemBrowserBootstrap.wait_for(browser_page) }
    browser_root.locator(".confirm-old-email .btn-primary").filter(visible: true).click
    expect(
      browser_root.locator(".dialog-body").filter(visible: true),
    ).to PlaywrightMatchers.contain_text(
      [browser_text_pattern(I18n.t("js.user.change_email.authorizing_old.confirm_success"))],
      useInnerText: true,
    )
    browser_root.locator(".dialog-footer .btn-primary").filter(visible: true).click

    # Confirm new email
    wait_for(timeout: Capybara.default_max_wait_time * 2) do
      ActionMailer::Base.deliveries.count === 2
    end

    confirm_new_link = get_link_from_email(:new)

    browser_page.goto(confirm_new_link).tap { SystemBrowserBootstrap.wait_for(browser_page) }

    browser_root.locator(".confirm-new-email .btn-primary").filter(visible: true).click

    expect(
      browser_root.locator(".dialog-body").filter(visible: true),
    ).to PlaywrightMatchers.contain_text(
      [browser_text_pattern(I18n.t("js.user.change_email.confirm_success"))],
      useInnerText: true,
    )
    browser_root.locator(".dialog-footer .btn-primary").filter(visible: true).click

    expect(user.reload.primary_email.email).to eq(new_email)
  end
end
