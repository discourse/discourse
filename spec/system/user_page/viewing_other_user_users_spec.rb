# frozen_string_literal: true

describe "Viewing another user's users preferences" do
  fab!(:admin) { Fabricate(:admin, username: "theadmin") }
  fab!(:user) { Fabricate(:user, username: "theuser", trust_level: 2, refresh_auto_groups: true) }

  let(:user_preferences_users_page) { PageObjects::Pages::UserPreferencesUsers.new }

  before do
    SearchIndexer.enable
    [admin, user].each { |indexed_user| SearchIndexer.index(indexed_user, force: true) }
    sign_in(admin)
  end

  it "excludes the viewed user, not the viewer, from the user choosers" do
    user_preferences_users_page.visit(user)

    muted_users_chooser = user_preferences_users_page.muted_users_chooser
    muted_users_chooser.search("the")

    expect(muted_users_chooser).to have_option_value(admin.username)
    expect(muted_users_chooser).to have_no_option_value(user.username)

    muted_users_chooser.collapse
    ignored_user_chooser = user_preferences_users_page.open_ignore_modal
    ignored_user_chooser.search("the")

    expect(ignored_user_chooser).to have_option_value(admin.username)
    expect(ignored_user_chooser).to have_no_option_value(user.username)
  end

  it "marks the settings the viewed user cannot change themself as staff only" do
    user_preferences_users_page.visit(user)

    expect(user_preferences_users_page).to have_section(:muted_users)
    expect(user_preferences_users_page.notice).to have_no_staff_only

    user.change_trust_level!(TrustLevel[0])
    page.refresh

    %i[ignored_users muted_users private_messages].each do |section|
      expect(user_preferences_users_page.notice(section)).to have_staff_only(
        text: I18n.t("js.user.staff_only_setting", username: user.username),
      )
    end

    sign_in(user)
    user_preferences_users_page.visit(user)

    expect(user_preferences_users_page).to have_no_section(:muted_users)
  end

  it "keeps the staff-only private messages section when the user has changed it" do
    SiteSetting.personal_message_enabled_groups = Group::AUTO_GROUPS[:staff]

    user_preferences_users_page.visit(user)

    expect(user_preferences_users_page).to have_no_section(:private_messages)

    user.user_option.update!(allow_private_messages: false)
    page.refresh

    expect(user_preferences_users_page.notice(:private_messages)).to have_staff_only
  end
end
