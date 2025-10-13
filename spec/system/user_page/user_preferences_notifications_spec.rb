# frozen_string_literal: true

describe "User preferences | Notifications", type: :system do
  fab!(:user)
  let(:user_preferences_page) { PageObjects::Pages::UserPreferences.new }

  before { sign_in(user) }

  describe "notify_on_linked_posts preference" do
    it "correctly updates the user_option when toggling the checkbox" do
      user_preferences_page.visit(user)
      find(".user-nav__preferences-notifications a").click

      # Verify initial state (default is true)
      checkbox = find(".pref-notify-on-linked-posts input[type='checkbox']")
      expect(checkbox).to be_checked
      expect(user.user_option.notify_on_linked_posts).to eq(true)

      # Uncheck the checkbox
      checkbox.click
      expect(checkbox).not_to be_checked

      # Save and verify database was updated
      click_button(I18n.t("js.save"))
      expect(page).to have_css(".saved")

      expect(user.user_option.reload.notify_on_linked_posts).to eq(false)

      # Refresh page and verify it persists
      page.refresh
      checkbox = find(".pref-notify-on-linked-posts input[type='checkbox']")
      expect(checkbox).not_to be_checked

      # Check it again and save
      checkbox.click
      expect(checkbox).to be_checked

      click_button(I18n.t("js.save"))
      expect(page).to have_css(".saved")

      expect(user.user_option.reload.notify_on_linked_posts).to eq(true)

      # Refresh page and verify it persists as checked
      page.refresh
      checkbox = find(".pref-notify-on-linked-posts input[type='checkbox']")
      expect(checkbox).to be_checked
    end
  end
end
