# frozen_string_literal: true

describe "User preferences for Interface", type: :system, js: true do
  fab!(:user) { Fabricate(:user) }
  let(:user_preferences_page) { PageObjects::Pages::UserPreferences.new }
  let(:user_preferences_interface_page) { PageObjects::Pages::UserPreferencesInterface.new }

  before { sign_in(user) }

  describe "Bookmarks" do
    it "changes the bookmark after notification preference" do
      skip(<<~TEXT) if ENV["CI"]
      This is currently failing on CI with the following:

      ```
      Failure/Error: expect(page).to have_content(I18n.t("js.saved"))
      expected `#<Capybara::Session>.has_content?("Saved!")` to be truthy, got false
      ```
      TEXT

      user_preferences_page.visit(user).click_interface_tab

      # preselects the default user_option.bookmark_auto_delete_preference value of 3 (clear_reminder)
      expect(user_preferences_interface_page).to have_bookmark_after_notification_mode(
        Bookmark.auto_delete_preferences[:clear_reminder],
      )

      user_preferences_interface_page.select_bookmark_after_notification_mode(
        Bookmark.auto_delete_preferences[:when_reminder_sent],
      ).save_changes

      expect(
        UserOption.exists?(
          user_id: user.id,
          bookmark_auto_delete_preference: Bookmark.auto_delete_preferences[:when_reminder_sent],
        ),
      ).to eq(true)
    end
  end
end
