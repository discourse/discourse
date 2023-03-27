# frozen_string_literal: true

RSpec.describe Chat::MarkAllUserChannelsRead do
  describe ".call" do
    subject(:result) { described_class.call(params) }

    let(:params) { { guardian: guardian } }
    let(:guardian) { Guardian.new(current_user) }

    fab!(:current_user) { Fabricate(:user) }

    fab!(:channel_1) { Fabricate(:chat_channel) }
    fab!(:channel_2) { Fabricate(:chat_channel) }
    fab!(:channel_3) { Fabricate(:chat_channel) }

    fab!(:other_user) { Fabricate(:user) }

    fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1, user: other_user) }
    fab!(:message_2) { Fabricate(:chat_message, chat_channel: channel_1, user: other_user) }
    fab!(:message_3) { Fabricate(:chat_message, chat_channel: channel_2, user: other_user) }
    fab!(:message_4) { Fabricate(:chat_message, chat_channel: channel_2, user: other_user) }
    fab!(:message_5) { Fabricate(:chat_message, chat_channel: channel_3, user: other_user) }
    fab!(:message_6) { Fabricate(:chat_message, chat_channel: channel_3, user: other_user) }

    fab!(:membership_1) do
      Fabricate(
        :user_chat_channel_membership,
        chat_channel: channel_1,
        user: current_user,
        following: true,
      )
    end
    fab!(:membership_2) do
      Fabricate(
        :user_chat_channel_membership,
        chat_channel: channel_2,
        user: current_user,
        following: true,
      )
    end
    fab!(:membership_3) do
      Fabricate(
        :user_chat_channel_membership,
        chat_channel: channel_3,
        user: current_user,
        following: true,
      )
    end

    context "when the user has no memberships" do
      let(:guardian) { Guardian.new(Fabricate(:user)) }

      it "sets the service result as successful" do
        expect(result).to be_a_success
      end

      it "returns the updated_memberships in context" do
        expect(result.updated_memberships).to eq([])
      end
    end

    context "when everything is fine" do
      fab!(:notification_1) do
        Fabricate(
          :notification,
          notification_type: Notification.types[:chat_mention],
          user: current_user,
        )
      end
      fab!(:notification_2) do
        Fabricate(
          :notification,
          notification_type: Notification.types[:chat_mention],
          user: current_user,
        )
      end

      let(:messages) { MessageBus.track_publish { result } }

      before do
        Chat::Mention.create!(
          notification: notification_1,
          user: current_user,
          chat_message: message_1,
        )
        Chat::Mention.create!(
          notification: notification_2,
          user: current_user,
          chat_message: message_3,
        )
      end

      it "sets the service result as successful" do
        expect(result).to be_a_success
      end

      it "updates the last_read_message_ids" do
        result
        expect(membership_1.reload.last_read_message_id).to eq(message_2.id)
        expect(membership_2.reload.last_read_message_id).to eq(message_4.id)
        expect(membership_3.reload.last_read_message_id).to eq(message_6.id)
      end

      it "does not update memberships where the user is not following" do
        membership_1.update!(following: false)
        result
        expect(membership_1.reload.last_read_message_id).to eq(nil)
      end

      it "does not use deleted messages for the last_read_message_id" do
        message_2.trash!
        result
        expect(membership_1.reload.last_read_message_id).to eq(message_1.id)
      end

      it "returns the updated_memberships in context" do
        expect(result.updated_memberships.map(&:channel_id)).to match_array(
          [channel_1.id, channel_2.id, channel_3.id],
        )
      end

      it "marks existing notifications for all affected channels as read" do
        expect { result }.to change {
          Notification.where(
            notification_type: Notification.types[:chat_mention],
            user: current_user,
            read: false,
          ).count
        }.by(-2)
      end

      it "publishes tracking state in bulk for affected channels" do
        message =
          messages.find { |m| m.channel == "/chat/bulk-user-tracking-state/#{current_user.id}" }

        expect(message.data).to eq(
          channel_1.id.to_s => {
            "last_read_message_id" => message_2.id,
            "membership_id" => membership_1.id,
            "mention_count" => 0,
            "unread_count" => 0,
          },
          channel_2.id.to_s => {
            "last_read_message_id" => message_4.id,
            "membership_id" => membership_2.id,
            "mention_count" => 0,
            "unread_count" => 0,
          },
          channel_3.id.to_s => {
            "last_read_message_id" => message_6.id,
            "membership_id" => membership_3.id,
            "mention_count" => 0,
            "unread_count" => 0,
          },
        )
      end
    end
  end
end
