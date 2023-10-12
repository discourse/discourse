# frozen_string_literal: true

describe "User preferences for Interface", type: :system do
  fab!(:user) { Fabricate(:user) }
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
end
