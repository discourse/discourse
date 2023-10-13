# frozen_string_literal: true

describe UsersController do
  describe "#perform_account_activation" do
    let!(:channel) { Fabricate(:category_channel, auto_join_users: true) }

    before do
      Jobs.run_immediately!
      UsersController.any_instance.stubs(:honeypot_or_challenge_fails?).returns(false)
      SiteSetting.send_welcome_message = false
      SiteSetting.chat_enabled = true
    end

    it "triggers the auto-join process" do
      user = Fabricate(:user, last_seen_at: 1.minute.ago, active: false)
      email_token = Fabricate(:email_token, user: user)

      put "/u/activate-account/#{email_token.token}"

      expect(response.status).to eq(200)
      membership = Chat::UserChatChannelMembership.find_by(user: user, chat_channel: channel)
      expect(membership.following).to eq(true)
    end
  end

  describe "#user_menu_bookmarks" do
    fab!(:chatters) { Fabricate(:group) }
    let(:current_user) { Fabricate(:user, group_ids: [chatters.id]) }
    let(:bookmark_message) { Fabricate(:chat_message) }
    let(:bookmark_user) { current_user }

    before do
      register_test_bookmarkable(Chat::MessageBookmarkable)
      SiteSetting.chat_allowed_groups = [chatters]
      sign_in(current_user)
    end

    it "does not return any unread notifications for chat bookmarks that the user no longer has access to" do
      bookmark_with_reminder =
        Fabricate(:bookmark, user: current_user, bookmarkable: bookmark_message)
      BookmarkReminderNotificationHandler.new(bookmark_with_reminder).send_notification

      bookmark_with_reminder.bookmarkable.update!(
        chat_channel: Fabricate(:private_category_channel),
      )

      get "/u/#{current_user.username}/user-menu-bookmarks"
      expect(response.status).to eq(200)

      notifications = response.parsed_body["notifications"]
      expect(notifications.size).to eq(0)
    end
  end
end
