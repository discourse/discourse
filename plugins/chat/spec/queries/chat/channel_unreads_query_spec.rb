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
    it "returns a correct unread count" do
      Fabricate(:chat_message, chat_channel: channel_1)

      expect(described_class.call(channel_id: channel_1.id, user_id: current_user.id)).to eq(
        { mention_count: 0, unread_count: 1 },
      )
    end
  end

  context "with unread mentions" do
    before { Jobs.run_immediately! }

    it "returns a correct unread mention" do
      message = Fabricate(:chat_message)
      notification =
        Notification.create!(
          notification_type: Notification.types[:chat_mention],
          user_id: current_user.id,
          data: { chat_message_id: message.id, chat_channel_id: channel_1.id }.to_json,
        )
      Chat::Mention.create!(notification: notification, user: current_user, chat_message: message)

      expect(described_class.call(channel_id: channel_1.id, user_id: current_user.id)).to eq(
        { mention_count: 1, unread_count: 0 },
      )
    end
  end

  context "with nothing unread" do
    it "returns a correct state" do
      expect(described_class.call(channel_id: channel_1.id, user_id: current_user.id)).to eq(
        { mention_count: 0, unread_count: 0 },
      )
    end
  end
end
