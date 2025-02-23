# frozen_string_literal: true

describe "Changing email", type: :system do
  fab!(:password) { "mysupersecurepassword" }
  fab!(:user) { Fabricate(:user, active: true, password: password) }
  let(:new_email) { "newemail@example.com" }
  let(:user_preferences_security_page) { PageObjects::Pages::UserPreferencesSecurity.new }
  let(:user_preferences_page) { PageObjects::Pages::UserPreferences.new }

  before { Jobs.run_immediately! }

  def generate_confirm_link
    visit "/my/preferences/account"

    email_dropdown = PageObjects::Components::SelectKit.new(".email-dropdown")
    expect(email_dropdown.visible?).to eq(true)
    email_dropdown.select_row_by_value("updateEmail")

    find("#change-email").fill_in with: "newemail@example.com"

    find(".save-button button").click

    wait_for(timeout: Capybara.default_max_wait_time) { ActionMailer::Base.deliveries.count === 1 }

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

    visit generate_confirm_link

    find(".confirm-new-email .btn-primary").click

    expect(page).to have_css(".dialog-body", text: I18n.t("js.user.change_email.confirm_success"))
    find(".dialog-footer .btn-primary").click

    expect(page).to have_current_path("/u/#{user.username}/preferences/account")
    expect(user_preferences_page).to have_primary_email(new_email)
  end

  it "works when user has totp 2fa" do
    SiteSetting.hide_email_address_taken = false

    second_factor = Fabricate(:user_second_factor_totp, user: user)
    sign_in user

    visit generate_confirm_link

    find(".confirm-new-email .btn-primary").click

    find(".second-factor-token-input").fill_in with: second_factor.totp_object.now

    find("button[type=submit]").click

    expect(page).to have_current_path("/u/#{user.username}/preferences/account")
    expect(user_preferences_page).to have_primary_email(new_email)
  end

  it "works when user has webauthn 2fa" do
    # enforced 2FA flow needs a user created > 5 minutes ago
    user.created_at = 6.minutes.ago
    user.save!

    sign_in user

    DiscourseWebauthn.stubs(:origin).returns(current_host + ":" + Capybara.server_port.to_s)
    options =
      ::Selenium::WebDriver::VirtualAuthenticatorOptions.new(
        user_verification: true,
        user_verified: true,
        resident_key: true,
      )
    authenticator = page.driver.browser.add_virtual_authenticator(options)

    user_preferences_security_page.visit(user)
    user_preferences_security_page.visit_second_factor(password)

    find(".security-key .new-security-key").click
    expect(user_preferences_security_page).to have_css("input#security-key-name")

    find(".d-modal__body input#security-key-name").fill_in(with: "First Key")
    find(".add-security-key").click

    expect(user_preferences_security_page).to have_css(".security-key .second-factor-item")

    visit generate_confirm_link

    find(".confirm-new-email .btn-primary").click

    find("#security-key-authenticate-button").click

    expect(page).to have_current_path("/u/#{user.username}/preferences/account")
    expect(user_preferences_page).to have_primary_email(new_email)
  ensure
    authenticator&.remove!
  end

  it "does not require login to verify" do
    second_factor = Fabricate(:user_second_factor_totp, user: user)
    sign_in user

    confirm_link = generate_confirm_link

    Capybara.reset_sessions! # log out

    visit confirm_link

    find(".confirm-new-email .btn-primary").click

    find(".second-factor-token-input").fill_in with: second_factor.totp_object.now

    find("button[type=submit]").click

    expect(page).to have_current_path("/latest")
    expect(user.reload.email).to eq(new_email)
  end

  it "makes admins verify old email" do
    user.update!(admin: true)
    sign_in user

    confirm_old_link = generate_confirm_link

    # Confirm old email
    visit confirm_old_link
    find(".confirm-old-email .btn-primary").click
    expect(page).to have_css(
      ".dialog-body",
      text: I18n.t("js.user.change_email.authorizing_old.confirm_success"),
    )
    find(".dialog-footer .btn-primary").click

    # Confirm new email
    wait_for(timeout: Capybara.default_max_wait_time) { ActionMailer::Base.deliveries.count === 2 }
    confirm_new_link = get_link_from_email(:new)

    visit confirm_new_link

    find(".confirm-new-email .btn-primary").click

    expect(page).to have_css(".dialog-body", text: I18n.t("js.user.change_email.confirm_success"))
    find(".dialog-footer .btn-primary").click

    expect(user.reload.email).to eq(new_email)
  end

  it "allows admin to verify old email while logged out" do
    user.update!(admin: true)
    sign_in user

    confirm_old_link = generate_confirm_link

    Capybara.reset_sessions! # log out

    # Confirm old email
    visit confirm_old_link
    find(".confirm-old-email .btn-primary").click
    expect(page).to have_css(
      ".dialog-body",
      text: I18n.t("js.user.change_email.authorizing_old.confirm_success"),
    )
    find(".dialog-footer .btn-primary").click

    # Confirm new email
    wait_for(timeout: Capybara.default_max_wait_time) { ActionMailer::Base.deliveries.count === 2 }
    confirm_new_link = get_link_from_email(:new)

    visit confirm_new_link

    find(".confirm-new-email .btn-primary").click

    expect(page).to have_css(".dialog-body", text: I18n.t("js.user.change_email.confirm_success"))
    find(".dialog-footer .btn-primary").click

    expect(user.reload.email).to eq(new_email)
  end
end
