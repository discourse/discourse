# frozen_string_literal: true

describe "User preferences for Interface", type: :system, js: true do
  fab!(:user) { Fabricate(:user) }

  let(:user_preferences_page) { PageObjects::Pages::UserPreferences.new }
  let(:user_preferences_interface_page) { PageObjects::Pages::UserPreferencesInterface.new }

  before { sign_in(user) }

  describe "Bookmarks" do
    let(:preferences) { Bookmark.auto_delete_preferences }
    let(:dropdown) { PageObjects::Components::SelectKit.new("#bookmark-after-notification-mode") }

    it "changes the bookmark after notification preference" do
      user_preferences_page.visit(user)
      user_preferences_page.click_interface_tab

      # preselects the default user_option.bookmark_auto_delete_preference value of 3 (clear_reminder)
      expect(dropdown).to have_selected_value(preferences[:clear_reminder])

      dropdown.select_row_by_value(preferences[:when_reminder_sent])
      user_preferences_interface_page.save_changes
    end
  end
end
