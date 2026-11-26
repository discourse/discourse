# frozen_string_literal: true

describe "Viewing another user's holidays region preference" do
  fab!(:admin)
  fab!(:user)

  let(:user_preferences_profile_page) { PageObjects::Pages::UserPreferencesProfile.new }
  let(:region_preference) { PageObjects::Components::DiscourseEvents::RegionPreference.new }

  before do
    SiteSetting.discourse_events_enabled = true
    sign_in(admin)
  end

  it "disables using the current region on another user's profile" do
    user_preferences_profile_page.visit(user)

    expect(region_preference.notice).to have_self_only
    expect(region_preference).to have_use_current_region_disabled

    user_preferences_profile_page.visit(admin)

    expect(region_preference.notice).to have_no_self_only
    expect(region_preference).to have_use_current_region_enabled
  end
end
