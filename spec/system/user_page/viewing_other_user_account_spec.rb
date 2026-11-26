# frozen_string_literal: true

describe "Viewing another user's account preferences" do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)

  let(:dialog) { PageObjects::Components::Dialog.new }
  let(:user_preferences_account_page) { PageObjects::Pages::UserPreferencesAccount.new }
  let(:user_preferences_email_page) { PageObjects::Pages::UserPreferencesEmail.new }

  before { sign_in(admin) }

  it "uses other-user wording when changing a staff member's email" do
    user_preferences_email_page.visit(moderator).change_email("new-moderator-email@example.com")

    expect(user_preferences_email_page).to have_success_message(
      I18n.t("js.user.change_email.success_staff_via_admin"),
    )
  end

  it "uses other-user wording when confirming a username change" do
    user_preferences_account_page.visit(user).edit_username("renamed_user")

    expect(dialog).to have_content(
      I18n.t("js.user.change_username.confirm_other", username: user.username),
    )
  end

  it "marks the username as staff only once the user can no longer change it" do
    user_preferences_account_page.visit(user)

    expect(user_preferences_account_page).to have_username_preference
    expect(user_preferences_account_page.notice).to have_no_staff_only

    SiteSetting.username_change_period = 0
    page.refresh

    expect(user_preferences_account_page.notice(:username)).to have_staff_only
  end

  it "disables exporting another user's data" do
    user_preferences_account_page.visit(user)

    expect(user_preferences_account_page.notice(:data_export)).to have_self_only
    expect(user_preferences_account_page).to have_request_archive_disabled
  end
end
