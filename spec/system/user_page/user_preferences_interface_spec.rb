# frozen_string_literal: true

describe "User preferences | Interface", type: :system do
  fab!(:user)
  let(:user_preferences_page) { PageObjects::Pages::UserPreferences.new }
  let(:user_preferences_interface_page) { PageObjects::Pages::UserPreferencesInterface.new }

  before { sign_in(user) }

  describe "Bookmarks" do
    it "changes the bookmark after notification preference" do
      user_preferences_page.visit(user)
      click_link(I18n.t("js.user.preferences_nav.interface"))

      dropdown = PageObjects::Components::SelectKit.new("#bookmark-after-notification-mode")

      # preselects the default user_option.bookmark_auto_delete_preference value of 3 (clear_reminder)
      expect(dropdown).to have_selected_value(Bookmark.auto_delete_preferences[:clear_reminder])

      dropdown.select_row_by_value(Bookmark.auto_delete_preferences[:when_reminder_sent])
      click_button(I18n.t("js.save"))

      # the preference page reloads after saving, so we need to poll the db
      try_until_success(timeout: 20) do
        expect(
          UserOption.exists?(
            user_id: user.id,
            bookmark_auto_delete_preference: Bookmark.auto_delete_preferences[:when_reminder_sent],
          ),
        ).to be_truthy
      end
    end
  end

  describe "Default Home Page" do
    context "when a user has picked a home page that is no longer available in top_menu" do
      it "shows the selected homepage" do
        SiteSetting.top_menu = "latest|hot"

        user.user_option.update!(homepage_id: UserOption::HOMEPAGES.key("unread"))
        user_preferences_page.visit(user)
        click_link(I18n.t("js.user.preferences_nav.interface"))

        dropdown = PageObjects::Components::SelectKit.new("#home-selector")

        expect(dropdown).to have_selected_name("Unread")
      end
    end

    it "shows only the available home pages from top_menu" do
      SiteSetting.top_menu = "latest|hot"

      user_preferences_page.visit(user)
      click_link(I18n.t("js.user.preferences_nav.interface"))

      dropdown = PageObjects::Components::SelectKit.new("#home-selector")
      dropdown.expand
      expect(dropdown).to have_option_value(UserOption::HOMEPAGES.key("latest"))
      expect(dropdown).to have_option_value(UserOption::HOMEPAGES.key("hot"))
      expect(dropdown).to have_no_option_value(UserOption::HOMEPAGES.key("top"))
      expect(dropdown).to have_no_option_value(UserOption::HOMEPAGES.key("new"))
    end
  end
end
