# frozen_string_literal: true

describe "User notifications", type: :system do
  fab!(:user) { Fabricate(:user, name: "Awesome Name") }
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

  describe "user group notifications" do
    fab!(:group) { Fabricate(:group, name: "Awesome_Group") }
    fab!(:topic) { Fabricate(:topic, title: "Group Mention Notification test") }
    fab!(:post) do
      Fabricate(
        :post,
        raw: "@#{group.name} this is a post to create a group mention notification",
        user: user,
        topic: topic,
      )
    end
    fab!(:user2) { Fabricate(:user) }
    fab!(:group_mention_notification) do
      Fabricate(:group_mentioned_notification, post: post, user: user2, group: group)
    end

    before { group.add(user2) }

    context "when prioritize_username_in_ux is false" do
      before do
        SiteSetting.prioritize_full_name_in_ux = true
        sign_in(user2)
      end

      it "shows the user name in the notification" do
        user_notifications_page.visit(user2)

        expect(user_notifications_page).to have_notification(group_mention_notification)

        notification = user_notifications_page.find_notification(group_mention_notification)

        expect(notification).to have_content(group.name)
        expect(notification).to have_content(user.name)
      end

      context "when user doesn't have a name" do
        before do
          user.name = nil
          user.save
        end

        it "shows the username in the notification instead" do
          user_notifications_page.visit(user2)

          expect(user_notifications_page).to have_notification(group_mention_notification)

          notification = user_notifications_page.find_notification(group_mention_notification)

          expect(notification).to have_content(group.name)
          expect(notification).to have_content(user.username)
        end
      end
    end
  end
end
