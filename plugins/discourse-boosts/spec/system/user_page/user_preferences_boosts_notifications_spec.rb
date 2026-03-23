# frozen_string_literal: true

describe "User preferences | Boosts notifications" do
  fab!(:user)
  let(:preferences_page) { PageObjects::Pages::UserPreferencesBoostsNotifications.new }

  before do
    SiteSetting.discourse_boosts_enabled = true
    sign_in(user)
  end

  it "updates boost_notifications_level" do
    preferences_page.visit(user)

    expect(preferences_page).to have_boost_notifications_level(1)

    preferences_page.change_boost_notifications_level(2)
    preferences_page.save_changes

    expect(user.user_option.reload.boost_notifications_level).to eq(2)

    page.refresh

    expect(preferences_page).to have_boost_notifications_level(2)
  end
end
