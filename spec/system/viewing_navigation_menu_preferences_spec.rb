# frozen_string_literal: true

describe "Viewing sidebar preferences", type: :system do
  let(:user_preferences_navigation_menu_page) do
    PageObjects::Pages::UserPreferencesNavigationMenu.new
  end

  before { SiteSetting.navigation_menu = "sidebar" }

  context "as an admin" do
    fab!(:admin)
    fab!(:user)

    before { sign_in(admin) }

    it "should be able to view navigation menu preferences of another user" do
      user.user_option.update!(
        sidebar_link_to_filtered_list: true,
        sidebar_show_count_of_new_items: true,
      )

      user_preferences_navigation_menu_page.visit(user)

      expect(user_preferences_navigation_menu_page).to have_navigation_menu_preference_checked(
        "pref-show-count-new-items",
      )
      expect(user_preferences_navigation_menu_page).to have_navigation_menu_preference_checked(
        "pref-link-to-filtered-list",
      )
    end
  end
end
