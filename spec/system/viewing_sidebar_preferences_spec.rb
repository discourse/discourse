# frozen_string_literal: true

describe 'Viewing sidebar preferences', type: :system, js: true do
  let(:user_preferences_sidebar_page) { PageObjects::Pages::UserPreferencesSidebar.new }

  before do
    SiteSetting.navigation_menu = "sidebar"
  end

  context 'as an admin' do
    fab!(:admin) { Fabricate(:admin) }
    fab!(:user) { Fabricate(:user) }
    fab!(:category) { Fabricate(:category) }
    fab!(:category2) { Fabricate(:category) }
    fab!(:category_sidebar_section_link) { Fabricate(:category_sidebar_section_link, user: user, linkable: category) }
    fab!(:category2_sidebar_section_link) { Fabricate(:category_sidebar_section_link, user: user, linkable: category2) }
    fab!(:tag) { Fabricate(:tag) }
    fab!(:tag2) { Fabricate(:tag) }
    fab!(:tag_sidebar_section_link) { Fabricate(:tag_sidebar_section_link, user: user, linkable: tag) }
    fab!(:tag2_sidebar_section_link) { Fabricate(:tag_sidebar_section_link, user: user, linkable: tag2) }

    before do
      sign_in(admin)
    end

    it 'should be able to view sidebar preferences of another user' do
      user.user_option.update!(sidebar_list_destination: "unread_new")

      user_preferences_sidebar_page.visit(user)

      expect(user_preferences_sidebar_page).to have_sidebar_categories_preference(category, category2)
      expect(user_preferences_sidebar_page).to have_sidebar_tags_preference(tag, tag2)
      expect(user_preferences_sidebar_page).to have_sidebar_list_destination_preference("unread_new")
    end
  end
end
