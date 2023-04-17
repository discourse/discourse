# frozen_string_literal: true

require "rails_helper"

describe Chat::ChannelUnreadsQuery do
  fab!(:channel_1) { Fabricate(:category_channel) }
  fab!(:current_user) { Fabricate(:user) }

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
    channel_1.add(current_user)
  end

  context "with unread message" do
    before { Fabricate(:chat_message, chat_channel: channel_1) }

    it "returns a correct unread count" do
      expect(
        described_class.call(channel_ids: [channel_1.id], user_id: current_user.id).first.to_h,
      ).to eq({ mention_count: 0, unread_count: 1, channel_id: channel_1.id })
    end

    context "for multiple channels" do
      fab!(:channel_2) { Fabricate(:category_channel) }

      it "returns accurate counts" do
        channel_2.add(current_user)
        Fabricate(:chat_message, chat_channel: channel_2)
        Fabricate(:chat_message, chat_channel: channel_2)

        expect(
          described_class.call(
            channel_ids: [channel_1.id, channel_2.id],
            user_id: current_user.id,
          ).map(&:to_h),
        ).to match_array(
          [
            { mention_count: 0, unread_count: 1, channel_id: channel_1.id },
            { mention_count: 0, unread_count: 2, channel_id: channel_2.id },
          ],
        )
      end
    end
  end

  context "with unread mentions" do
    before { Jobs.run_immediately! }

    def create_mention(message, channel)
      notification =
        Notification.create!(
          notification_type: Notification.types[:chat_mention],
          user_id: current_user.id,
          data: { chat_message_id: message.id, chat_channel_id: channel.id }.to_json,
        )
      Chat::Mention.create!(notification: notification, user: current_user, chat_message: message)
    end

    it "returns a correct unread mention" do
      message = Fabricate(:chat_message, chat_channel: channel_1)
      create_mention(message, channel_1)

      expect(
        described_class.call(channel_ids: [channel_1.id], user_id: current_user.id).first.to_h,
      ).to eq({ mention_count: 1, unread_count: 1, channel_id: channel_1.id })
    end

    context "for multiple channels" do
      fab!(:channel_2) { Fabricate(:category_channel) }

      it "returns accurate counts" do
        message = Fabricate(:chat_message, chat_channel: channel_1)
        create_mention(message, channel_1)

        channel_2.add(current_user)
        Fabricate(:chat_message, chat_channel: channel_2)
        message_2 = Fabricate(:chat_message, chat_channel: channel_2)
        create_mention(message_2, channel_2)

        expect(
          described_class.call(
            channel_ids: [channel_1.id, channel_2.id],
            user_id: current_user.id,
          ).map(&:to_h),
        ).to match_array(
          [
            { mention_count: 1, unread_count: 1, channel_id: channel_1.id },
            { mention_count: 1, unread_count: 2, channel_id: channel_2.id },
          ],
        )
      end
    end
  end

  context "with nothing unread" do
    it "returns a correct state" do
      expect(
        described_class.call(channel_ids: [channel_1.id], user_id: current_user.id).first.to_h,
      ).to eq({ mention_count: 0, unread_count: 0, channel_id: channel_1.id })
    end
  end
end
