# frozen_string_literal: true

describe "User preferences | Navigation menu", type: :system do
  fab!(:user)
  let(:everyone_group) { Group[:everyone] }
  let(:user_preferences_page) { PageObjects::Pages::UserPreferences.new }

  describe "when visiting the user's preferences page" do
    it "should allow the user to scroll the horizontal navigation menu when window width is narrow" do
      resize_window(width: 650) do # narrow enough to hide some links, but higher than 640px so we don't trigger mobile styling
        sign_in(user)

        user_preferences_page.visit(user)

        expect(user_preferences_page).to have_interface_link_not_visible
        expect(user_preferences_page).to have_account_link_visible

        user_preferences_page.click_secondary_navigation_menu_scroll_right

        expect(user_preferences_page).to have_interface_link_visible
        expect(user_preferences_page).to have_account_link_not_visible

        user_preferences_page.click_secondary_navigation_menu_scroll_left

        expect(user_preferences_page).to have_interface_link_not_visible
        expect(user_preferences_page).to have_account_link_visible
      end
    end
  end
end
