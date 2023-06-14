# frozen_string_literal: true

describe "Viewing sidebar preferences", type: :system do
  let(:user_preferences_navigation_menu_page) do
    PageObjects::Pages::UserPreferencesNavigationMenu.new
  end

  before { SiteSetting.navigation_menu = "sidebar" }

  context "as an admin" do
    fab!(:admin) { Fabricate(:admin) }
    fab!(:user) { Fabricate(:user) }
    fab!(:category) { Fabricate(:category) }
    fab!(:category2) { Fabricate(:category) }
    fab!(:category_sidebar_section_link) do
      Fabricate(:category_sidebar_section_link, user: user, linkable: category)
    end
    fab!(:category2_sidebar_section_link) do
      Fabricate(:category_sidebar_section_link, user: user, linkable: category2)
    end
    fab!(:tag) { Fabricate(:tag) }
    fab!(:tag2) { Fabricate(:tag) }
    fab!(:tag_sidebar_section_link) do
      Fabricate(:tag_sidebar_section_link, user: user, linkable: tag)
    end
    fab!(:tag2_sidebar_section_link) do
      Fabricate(:tag_sidebar_section_link, user: user, linkable: tag2)
    end

    before { sign_in(admin) }

    it "should be able to view navigation menu preferences of another user" do
      user.user_option.update!(sidebar_list_destination: "unread_new")

      user_preferences_navigation_menu_page.visit(user)

      expect(user_preferences_navigation_menu_page).to have_navigation_menu_categories_preference(
        category,
        category2,
      )
      expect(user_preferences_navigation_menu_page).to have_navigation_menu_tags_preference(
        tag,
        tag2,
      )
      expect(
        user_preferences_navigation_menu_page,
      ).to have_navigation_menu_list_destination_preference("unread_new")
    end
  end
end
