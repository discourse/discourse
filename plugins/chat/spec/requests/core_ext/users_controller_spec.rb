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
      SiteSetting.chat_allowed_groups = chatters
      sign_in(current_user)
    end

    after { DiscoursePluginRegistry.reset_register!(:bookmarkables) }

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

  describe "#show_card" do
    fab!(:user) { Fabricate(:user) }
    fab!(:another_user) { Fabricate(:user) }

    before do
      SiteSetting.chat_enabled = true
      SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
      SiteSetting.direct_message_enabled_groups = Group::AUTO_GROUPS[:everyone]
    end

    context "when the card belongs to the current user" do
      before { sign_in(user) }

      it "returns that the user can message themselves" do
        user.user_option.update!(hide_profile: false)
        user.user_option.update!(chat_enabled: true)
        get "/u/#{user.username}/card.json"
        expect(response).to be_successful
        expect(response.parsed_body["user"]["can_chat_user"]).to eq(true)
      end

      it "returns that the user can message themselves when the profile is hidden" do
        user.user_option.update!(hide_profile: true)
        user.user_option.update!(chat_enabled: true)
        get "/u/#{user.username}/card.json"
        expect(response).to be_successful
        expect(response.parsed_body["user"]["can_chat_user"]).to eq(true)
      end
    end

    context "when hidden users" do
      before do
        sign_in(another_user)
        user.user_option.update!(hide_profile: true)
      end

      it "returns the correct partial response when the user has chat enabled" do
        user.user_option.update!(chat_enabled: true)
        get "/u/#{user.username}/card.json"
        expect(response).to be_successful
        expect(response.parsed_body["user"]["profile_hidden"]).to eq(true)
        expect(response.parsed_body["user"]["can_chat_user"]).to eq(true)
      end

      it "returns the correct partial response when the user has chat disabled" do
        user.user_option.update!(chat_enabled: false)
        get "/u/#{user.username}/card.json"
        expect(response).to be_successful
        expect(response.parsed_body["user"]["profile_hidden"]).to eq(true)
        expect(response.parsed_body["user"]["can_chat_user"]).to eq(false)
      end
    end
  end
end
