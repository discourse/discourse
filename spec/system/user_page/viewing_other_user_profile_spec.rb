# frozen_string_literal: true

describe "Viewing another user's profile preferences" do
  fab!(:admin)
  fab!(:user)

  let(:user_preferences_profile_page) { PageObjects::Pages::UserPreferencesProfile.new }

  before { sign_in(admin) }

  it "disables using the current timezone on another user's profile" do
    user_preferences_profile_page.visit(user)

    expect(user_preferences_profile_page.notice(:timezone)).to have_self_only
    expect(user_preferences_profile_page).to have_use_current_timezone_disabled

    user_preferences_profile_page.visit(admin)

    expect(user_preferences_profile_page.notice(:timezone)).to have_no_self_only
    expect(user_preferences_profile_page).to have_use_current_timezone_enabled
  end

  it "marks the settings the viewed user cannot change themself as staff only" do
    SiteSetting.profile_background_allowed_groups = Group::AUTO_GROUPS[:trust_level_4]
    SiteSetting.user_card_background_allowed_groups = Group::AUTO_GROUPS[:trust_level_4]
    Fabricate(:user_field, name: "Open field", editable: true)
    Fabricate(:user_field, name: "Locked field", editable: false)

    user_preferences_profile_page.visit(user)

    expect(user_preferences_profile_page.notice(:profile_header)).to have_staff_only
    expect(user_preferences_profile_page.notice(:card_background)).to have_staff_only
    expect(user_preferences_profile_page).to have_user_field("Open field")
    expect(user_preferences_profile_page.notice).to have_staff_only(count: 3)
    expect(user_preferences_profile_page).to have_staff_only_user_field("Locked field")
  end

  it "keeps a staff-only background visible when the user already has one" do
    SiteSetting.profile_background_allowed_groups = Group::AUTO_GROUPS[:staff]
    user.user_profile.update!(profile_background_upload: Fabricate(:image_upload))

    user_preferences_profile_page.visit(user)

    expect(user_preferences_profile_page.notice(:profile_header)).to have_staff_only
  end
end
