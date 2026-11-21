# frozen_string_literal: true

describe "User preferences | Notifications" do
  fab!(:user)
  let(:user_preferences_notifications_page) { PageObjects::Pages::UserPreferencesNotifications.new }

  before { sign_in(user) }

  describe "notify_on_linked_posts preference" do
    it "correctly updates the user_option when toggling the checkbox" do
      user_preferences_notifications_page.visit(user)

      expect(user_preferences_notifications_page).to have_notify_on_linked_posts_enabled
      expect(user.user_option.notify_on_linked_posts).to eq(true)

      user_preferences_notifications_page.toggle_notify_on_linked_posts
      user_preferences_notifications_page.save_changes

      expect(user.user_option.reload.notify_on_linked_posts).to eq(false)

      page.refresh

      expect(user_preferences_notifications_page).to have_notify_on_linked_posts_disabled

      user_preferences_notifications_page.toggle_notify_on_linked_posts
      user_preferences_notifications_page.save_changes

      expect(user.user_option.reload.notify_on_linked_posts).to eq(true)

      page.refresh

      expect(user_preferences_notifications_page).to have_notify_on_linked_posts_enabled
    end
  end

  describe "notification toast preference" do
    it "is hidden unless the site enables toast notifications" do
      user_preferences_notifications_page.visit(user)
      expect(page).to have_no_css(".pref-show-notification-toasts")
    end

    it "saves the user's opt-in" do
      SiteSetting.enable_desktop_notification_toasts = true
      user_preferences_notifications_page.visit(user)

      find(".pref-show-notification-toasts input[type='checkbox']").check
      user_preferences_notifications_page.save_changes

      expect(user.user_option.reload.show_notification_toasts).to eq(true)
      page.refresh
      expect(page).to have_css(".pref-show-notification-toasts input[type='checkbox']:checked")
    end
  end
end
