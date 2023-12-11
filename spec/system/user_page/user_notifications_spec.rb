# frozen_string_literal: true

describe "User notifications", type: :system do
  fab!(:user)
  let(:user_notifications_page) { PageObjects::Pages::UserNotifications.new }

  fab!(:read_notification) { Fabricate(:notification, user: user, read: true) }
  fab!(:unread_notification) { Fabricate(:notification, user: user, read: false) }

  before { sign_in(user) }

  describe "filtering" do
    it "saves custom picture and system assigned pictures" do
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
end
