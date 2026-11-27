# frozen_string_literal: true

describe "DiscourseRewind | viewing another user's preferences" do
  fab!(:admin) { Fabricate(:admin, created_at: DateTime.parse("2020-01-01")) }
  fab!(:other_user) { Fabricate(:user, created_at: DateTime.parse("2020-01-01")) }

  let(:rewind_page) { PageObjects::Pages::Rewind.new }
  let(:sidebar) { PageObjects::Components::NavigationMenu::Sidebar.new }

  before do
    SiteSetting.discourse_rewind_enabled = true
    freeze_time DateTime.parse("2022-12-05")
    sign_in(admin)
  end

  it "does not change the viewer's rewind state when saving the other user's preferences" do
    rewind_page.visit_preferences(other_user)

    expect(rewind_page).to have_rewind_notification_active

    rewind_page.disable_rewind_preference

    expect(rewind_page).to have_saved_preferences
    expect(rewind_page).to have_rewind_notification_active

    page.refresh

    expect(rewind_page).to have_rewind_preference_disabled
  end

  it "lists the rewind preferences in the user nav sidebar of the user's admin page" do
    SiteSetting.navigation_menu = "sidebar"
    SiteSetting.sidebar_user_navigation = true

    PageObjects::Pages::AdminUser.new.visit(other_user)
    sidebar.click_section_header("user-nav-preferences")

    expect(sidebar).to have_section_link(I18n.t("js.discourse_rewind.title"))
  end

  context "when the viewer's account is less than one month old" do
    before { admin.update!(created_at: DateTime.parse("2022-11-20")) }

    it "shows the rewind preferences nav link and activity tab for an eligible user" do
      rewind_page.visit_user_preferences(other_user)

      expect(rewind_page).to have_rewind_preferences_nav

      rewind_page.visit_user_activity(other_user)

      expect(rewind_page).to have_rewind_tab
    end
  end
end
