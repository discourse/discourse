# frozen_string_literal: true

RSpec.describe NotificationsController do
  context "when logged in" do
    fab!(:chatters) { Fabricate(:group) }
    fab!(:user) { Fabricate(:user, group_ids: [chatters.id]) }
    fab!(:user2) { Fabricate(:user, group_ids: [chatters.id]) }
    fab!(:dm1) { Fabricate(:direct_message) }
    fab!(:direct_message_channel1) { Fabricate(:direct_message_channel, chatable: dm1) }
    fab!(:dm2) { Fabricate(:direct_message) }
    fab!(:direct_message_channel2) { Fabricate(:direct_message_channel, chatable: dm2) }
    fab!(:channel_1) { Fabricate(:category_channel) }

    before do
      Jobs.run_immediately!
      SiteSetting.chat_enabled = true
      SiteSetting.chat_allowed_groups = [chatters.id]
      channel_1.add(user)
      sign_in(user)
    end

    def create_dm(user, channel, dm)
      Fabricate(
        :user_chat_channel_membership_for_dm,
        chat_channel: channel,
        user: user,
        following: true,
      )
      Chat::DirectMessageUser.create!(direct_message: dm, user: user)

      msg = Fabricate(:chat_message, user: user, chat_channel: channel)

      channel.update!(last_message: msg)
      channel.last_message.update!(created_at: 1.day.ago)
    end

    def create_mention(user, message, channel)
      notification =
        Notification.create!(
          notification_type: Notification.types[:chat_mention],
          user_id: user.id,
          data: { chat_message_id: message.id, chat_channel_id: channel.id }.to_json,
        )
      Chat::UserMention.create!(notifications: [notification], user: user, chat_message: message)
    end

    describe "#totals" do
      it "has a total of 0 by default" do
        sign_in(user)
        get "/notifications/totals.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["chat_notifications"]).to eq(0)
      end

      it "has a total of 1 when user has a DM" do
        create_dm(user, direct_message_channel1, dm1)

        get "/notifications/totals.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["chat_notifications"]).to eq(1)

        create_dm(user, direct_message_channel2, dm2)

        get "/notifications/totals.json"

        expect(response.parsed_body["chat_notifications"]).to eq(2)

        message = Fabricate(:chat_message, chat_channel: channel_1)
        create_mention(user, message, channel_1)

        get "/notifications/totals.json"

        expect(response.parsed_body["chat_notifications"]).to eq(3)
      end
    end
  end
end
