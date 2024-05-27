# frozen_string_literal: true

describe "User notifications", type: :system do
  fab!(:user)
  let(:user_notifications_page) { PageObjects::Pages::UserNotifications.new }
  let(:user_page) { PageObjects::Pages::User.new }

  fab!(:read_notification) { Fabricate(:notification, user: user, read: true) }
  fab!(:unread_notification) { Fabricate(:notification, user: user, read: false) }

  before { sign_in(user) }

  describe "filtering" do
    it "correctly filters all / read / unread notifications" do
      user_notifications_page.visit(user)
      user_notifications_page.filter_dropdown
      expect(user_notifications_page).to have_selected_filter_value("all")
      expect(user_notifications_page).to have_notification(read_notification)
      expect(user_notifications_page).to have_notification(unread_notification)

      user_notifications_page.set_filter_value("read")

      expect(user_notifications_page).to have_notification(read_notification)
      expect(user_notifications_page).to have_no_notification(unread_notification)

      user_notifications_page.set_filter_value("unread")

      expect(user_notifications_page).to have_no_notification(read_notification)
      expect(user_notifications_page).to have_notification(unread_notification)
    end
  end

  describe "setNotificationLimit & addBeforeLoadMoreNotificationsCallback plugin-api functions" do
    it "Allows blocking loading via callback and limit" do
      user_page.visit(user)

      page.execute_script <<~JS
        require("discourse/lib/plugin-api").withPluginApi("1.19.0", (api) => {
          api.setNotificationsLimit(1);

          api.addBeforeLoadMoreNotificationsCallback(() => {
            return false;
          })
        })
      JS

      user_page.click_primary_navigation_item("notifications")

      # It is 1 here because we blocked infinite scrolling. Even though the limit is 1,
      # without the callback, we would have 2 items here as it immediately fires another request.
      expect(user_notifications_page).to have_notification_count_of(1)
    end
  end
end
