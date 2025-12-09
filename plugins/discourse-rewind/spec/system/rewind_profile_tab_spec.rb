# frozen_string_literal: true

describe "DiscourseRewind | rewind profile link", type: :system do
  fab!(:current_user, :user)

  let(:rewind_page) { PageObjects::Pages::Rewind.new }
  let(:user_menu) { PageObjects::Components::UserMenu.new }

  before do
    sign_in(current_user)
    freeze_time(DateTime.parse("2022-12-05"))
  end

  it "does not show the profile link when the plugin is disabled" do
    SiteSetting.discourse_rewind_enabled = false

    visit("/")
    user_menu.open
    user_menu.click_profile_tab

    expect(rewind_page).to have_no_rewind_profile_link
  end

  it "shows the profile link when the plugin is enabled" do
    SiteSetting.discourse_rewind_enabled = true

    visit("/")
    user_menu.open
    user_menu.click_profile_tab

    expect(rewind_page).to have_rewind_profile_link
  end
end
