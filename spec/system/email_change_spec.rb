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

    visit generate_confirm_link

    find(".confirm-new-email .btn-primary").click

    expect(page).to have_css(".dialog-body", text: I18n.t("js.user.change_email.confirm_success"))
    find(".dialog-footer .btn-primary").click

    try_until_success(timeout: Capybara.default_max_wait_time * 2) do
      expect(user.reload.primary_email.email).to eq(new_email)
    end
  end

  it "works when user has totp 2fa", dump_threads_on_failure: true do
    SiteSetting.hide_email_address_taken = false

    second_factor = Fabricate(:user_second_factor_totp, user: user)
    sign_in user

    visit generate_confirm_link

    find(".confirm-new-email .btn-primary").click
    find(".second-factor-token-input").fill_in with: second_factor.totp_object.now
    find("button[type=submit]").click

    try_until_success(timeout: Capybara.default_max_wait_time * 2) do
      expect(user.reload.primary_email.email).to eq(new_email)
    end
  end

  it "works when user has webauthn 2fa" do
    with_security_key(user) do
      sign_in user
      visit generate_confirm_link

      find(".confirm-new-email .btn-primary").click
      find("#security-key-authenticate-button").click

      try_until_success(timeout: Capybara.default_max_wait_time * 2) do
        expect(user.reload.primary_email.email).to eq(new_email)
      end
    end
  end

  it "does not require login to confirm email change" do
    second_factor = Fabricate(:user_second_factor_totp, user: user)
    sign_in user

    confirm_link = generate_confirm_link

    Capybara.reset_sessions! # log out

    visit confirm_link

    find(".confirm-new-email .btn-primary").click
    find(".second-factor-token-input").fill_in with: second_factor.totp_object.now
    find("button[type=submit]:not([disabled])").click

    try_until_success(timeout: Capybara.default_max_wait_time * 2) do
      expect(user.reload.primary_email.email).to eq(new_email)
    end
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
    wait_for(timeout: Capybara.default_max_wait_time * 2) do
      ActionMailer::Base.deliveries.count === 2
    end

    confirm_new_link = get_link_from_email(:new)

    visit confirm_new_link

    find(".confirm-new-email .btn-primary").click

    expect(page).to have_css(".dialog-body", text: I18n.t("js.user.change_email.confirm_success"))
    find(".dialog-footer .btn-primary").click

    try_until_success(timeout: Capybara.default_max_wait_time * 2) do
      expect(user.reload.primary_email.email).to eq(new_email)
    end
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
    wait_for(timeout: Capybara.default_max_wait_time * 2) do
      ActionMailer::Base.deliveries.count === 2
    end

    confirm_new_link = get_link_from_email(:new)

    visit confirm_new_link

    find(".confirm-new-email .btn-primary").click

    expect(page).to have_css(".dialog-body", text: I18n.t("js.user.change_email.confirm_success"))
    find(".dialog-footer .btn-primary").click

    try_until_success(timeout: Capybara.default_max_wait_time * 2) do
      expect(user.reload.primary_email.email).to eq(new_email)
    end
  end
end
