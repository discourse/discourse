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

    before do
      Jobs.run_immediately!
      SiteSetting.chat_enabled = true
      SiteSetting.chat_allowed_groups = chatters.id
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

    describe "#totals" do
      it "has a total of 0 chat notifications by default" do
        get "/notifications/totals.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["chat_notifications"]).to eq(0)
      end

      it "returns the correct chat notifications count for unread DMs" do
        create_dm(user, direct_message_channel1, dm1)

        get "/notifications/totals.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["chat_notifications"]).to eq(1)

        create_dm(user, direct_message_channel2, dm2)

        get "/notifications/totals.json"

        expect(response.parsed_body["chat_notifications"]).to eq(2)
      end
    end
  end
end
