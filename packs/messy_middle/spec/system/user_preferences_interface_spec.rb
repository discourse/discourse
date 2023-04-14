# frozen_string_literal: true

describe "User preferences for Interface", type: :system, js: true do
  fab!(:user) { Fabricate(:user) }
  let(:user_preferences_page) { PageObjects::Pages::UserPreferences.new }

  before { sign_in(user) }

  describe "Bookmarks" do
    it "changes the bookmark after notification preference" do
      user_preferences_page.visit(user)
      click_link "Interface"

      # preselects the default user_option.bookmark_auto_delete_preference value of 3 (clear_reminder)
      expect(page).to have_css(
        "#boookmark-after-notification-mode .select-kit-header[data-value='#{Bookmark.auto_delete_preferences[:clear_reminder]}']",
      )
      page.find("#boookmark-after-notification-mode").click
      page.find(
        ".select-kit-row[data-value=\"#{Bookmark.auto_delete_preferences[:when_reminder_sent]}\"]",
      ).click

      click_button "Save Changes"

      # the preference page reloads after saving, so we need to poll the db
      try_until_success do
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
