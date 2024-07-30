# frozen_string_literal: true

RSpec.describe Chat::Api::ChannelsInvitesController do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:channel_1) { Fabricate(:chat_channel) }
  fab!(:user_1) { Fabricate(:user) }
  fab!(:user_2) { Fabricate(:user) }

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
    channel_1.add(current_user)
    sign_in(current_user)
  end

  describe "create" do
    describe "success" do
      it "works" do
        expect {
          post "/chat/api/channels/#{channel_1.id}/invites?user_ids=#{user_1.id},#{user_2.id}"
        }.to change {
          Notification.where(
            notification_type: Notification.types[:chat_invitation],
            user_id: [user_1.id, user_2.id],
          ).count
        }.by(2)

        expect(response.status).to eq(200)
      end
    end

    describe "missing user_ids" do
      fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1) }

      it "returns a 400" do
        post "/chat/api/channels/#{channel_1.id}/invites"

        expect(response.status).to eq(400)
      end
    end

    describe "message_id param" do
      fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1) }

      it "works" do
        post "/chat/api/channels/#{channel_1.id}/invites?user_ids=#{user_1.id},#{user_2.id}&message_id=#{message_1.id}"

        expect(JSON.parse(Notification.last.data)["chat_message_id"]).to eq(message_1.id)
        expect(response.status).to eq(200)
      end
    end

    describe "current user can't view channel" do
      fab!(:channel_1) { Fabricate(:private_category_channel) }

      it "returns a 403" do
        post "/chat/api/channels/#{channel_1.id}/invites?user_ids=#{user_1.id},#{user_2.id}"

        expect(response.status).to eq(403)
      end
    end

    describe "channel doesn’t exist" do
      it "returns a 404" do
        post "/chat/api/channels/-1/invites?user_ids=#{user_1.id},#{user_2.id}"

        expect(response.status).to eq(404)
      end
    end
  end
end
