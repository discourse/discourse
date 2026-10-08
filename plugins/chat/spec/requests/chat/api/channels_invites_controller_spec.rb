# frozen_string_literal: true

RSpec.describe Chat::Api::ChannelsInvitesController do
  fab!(:current_user, :user)
  fab!(:channel_1, :chat_channel)
  fab!(:user_1, :user)
  fab!(:user_2, :user)

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
    channel_1.add(current_user)
    sign_in(current_user)
  end

  describe "create" do
    describe "success" do
      it "notifies the invited users" do
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

      it "skips users who mute or ignore a nonstaff inviter without skipping other eligible users" do
        Fabricate(:muted_user, user: user_1, muted_user: current_user)
        Fabricate(:ignored_user, user: user_2, ignored_user: current_user)
        unblocked_user = Fabricate(:user)
        pm_restricted_user = Fabricate(:user)
        pm_restricted_user.user_option.update!(allow_private_messages: false)
        recipient_ids = [user_1.id, user_2.id, unblocked_user.id, pm_restricted_user.id]

        expect {
          post "/chat/api/channels/#{channel_1.id}/invites?user_ids=#{recipient_ids.join(",")}"
        }.to change {
          Notification.where(
            notification_type: Notification.types[:chat_invitation],
            user_id: recipient_ids,
          ).count
        }.by(2)

        expect(
          Notification.where(
            notification_type: Notification.types[:chat_invitation],
            user_id: recipient_ids,
          ).pluck(:user_id),
        ).to contain_exactly(unblocked_user.id, pm_restricted_user.id)
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq("success" => "OK")
      end

      context "when the inviter is staff" do
        fab!(:current_user, :admin)

        it "notifies users who mute or ignore the inviter" do
          Fabricate(:muted_user, user: user_1, muted_user: current_user)
          Fabricate(:ignored_user, user: user_2, ignored_user: current_user)

          expect {
            post "/chat/api/channels/#{channel_1.id}/invites?user_ids=#{user_1.id},#{user_2.id}"
          }.to change {
            Notification.where(
              notification_type: Notification.types[:chat_invitation],
              user_id: [user_1.id, user_2.id],
            ).count
          }.by(2)

          expect(response).to have_http_status(:ok)
          expect(response.parsed_body).to eq("success" => "OK")
        end
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

      it "includes the message in each notification" do
        post "/chat/api/channels/#{channel_1.id}/invites?user_ids=#{user_1.id},#{user_2.id}&message_id=#{message_1.id}"

        expect(JSON.parse(Notification.last.data)["chat_message_id"]).to eq(message_1.id)
        expect(response.status).to eq(200)
      end
    end

    describe "current user can't join channel" do
      fab!(:channel_1, :private_category_channel)

      it "returns a 403" do
        post "/chat/api/channels/#{channel_1.id}/invites?user_ids=#{user_1.id},#{user_2.id}"

        expect(response.status).to eq(403)
      end
    end

    describe "current user can view but not join channel" do
      fab!(:group)

      before do
        channel_1.chatable.set_permissions(group => :readonly)
        channel_1.chatable.save!
        group.add(current_user)
      end

      it "returns a 403" do
        post "/chat/api/channels/#{channel_1.id}/invites?user_ids=#{user_1.id},#{user_2.id}"

        expect(response.status).to eq(403)
      end
    end

    describe "rate limiting" do
      it "rate limits invites" do
        RateLimiter.enable

        6.times { post "/chat/api/channels/#{channel_1.id}/invites?user_ids=#{user_1.id}" }

        expect(response.status).to eq(429)
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
