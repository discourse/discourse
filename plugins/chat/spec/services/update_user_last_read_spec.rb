# frozen_string_literal: true

RSpec.describe(Chat::Service::UpdateUserLastRead) do
  let(:guardian) { Guardian.new(current_user) }

  context "when channel_id is not provided" do
    subject(:result) { described_class.call(guardian: guardian, user_id: current_user.id) }
    fab!(:current_user) { Fabricate(:admin) }

    it { is_expected.to fail_to_find_a_model(:membership) }
  end

  context "when user_id is not provided" do
    subject(:result) { described_class.call(guardian: guardian, channel_id: channel.id) }
    fab!(:current_user) { Fabricate(:admin) }
    fab!(:channel) { Fabricate(:chat_channel) }

    it { is_expected.to fail_to_find_a_model(:membership) }
  end

  context "when user has no membership" do
    subject(:result) do
      described_class.call(guardian: guardian, user_id: current_user.id, channel_id: channel.id)
    end
    fab!(:current_user) { Fabricate(:admin) }
    fab!(:channel) { Fabricate(:chat_channel) }

    it { is_expected.to fail_to_find_a_model(:membership) }
  end

  context "when user can’t access the channel" do
    subject(:result) do
      described_class.call(
        guardian: guardian,
        user_id: current_user.id,
        channel_id: membership.chat_channel.id,
      )
    end
    fab!(:current_user) { Fabricate(:user) }
    fab!(:membership) do
      Fabricate(
        :user_chat_channel_membership,
        user: current_user,
        chat_channel: Fabricate(:private_category_channel),
      )
    end

    it { is_expected.to fail_a_policy(:invalid_access) }
  end

  context "when message_id is older than membership's last_read_message_id" do
    subject(:result) do
      described_class.call(
        guardian: guardian,
        user_id: current_user.id,
        channel_id: membership.chat_channel.id,
        message_id: -2,
      )
    end
    fab!(:current_user) { Fabricate(:user) }
    fab!(:membership) { Fabricate(:user_chat_channel_membership, user: current_user) }

    before { membership.update!(last_read_message_id: -1) }

    it { is_expected.to fail_a_policy(:ensure_message_id_recency) }
  end

  context "when message doesn’t exist" do
    subject(:result) do
      described_class.call(
        guardian: guardian,
        user_id: current_user.id,
        channel_id: membership.chat_channel.id,
        message_id: 2,
      )
    end
    fab!(:current_user) { Fabricate(:user) }
    fab!(:membership) { Fabricate(:user_chat_channel_membership, user: current_user) }

    before { membership.update!(last_read_message_id: 1) }

    it { is_expected.to fail_a_policy(:ensure_message_exists) }
  end

  context "when params are valid" do
    subject(:result) do
      described_class.call(
        guardian: guardian,
        user_id: current_user.id,
        channel_id: membership.chat_channel.id,
        message_id: message_1.id,
      )
    end

    fab!(:current_user) { Fabricate(:user) }
    fab!(:membership) { Fabricate(:user_chat_channel_membership, user: current_user) }
    fab!(:message_1) { Fabricate(:chat_message, chat_channel: membership.chat_channel) }

    before { Jobs.run_immediately! }

    it "sets the service result as successful" do
      expect(result).to be_a_success
    end

    it "updates the last_read message id" do
      expect { result }.to change { membership.reload.last_read_message_id }.to(message_1.id)
    end

    it "marks existing notifications related to the message as read" do
      expect {
        notification =
          Fabricate(
            :notification,
            notification_type: Notification.types[:chat_mention],
            user: current_user,
          )

        # FIXME: we need a better way to create proper chat mention
        ChatMention.create!(notification: notification, user: current_user, chat_message: message_1)
      }.to change {
        Notification.where(
          notification_type: Notification.types[:chat_mention],
          user: current_user,
          read: false,
        ).count
      }.by(1)

      expect { result }.to change {
        Notification.where(
          notification_type: Notification.types[:chat_mention],
          user: current_user,
          read: false,
        ).count
      }.by(-1)
    end

    it "publishes new last read to clients" do
      messages = MessageBus.track_publish { result }

      expect(messages.map(&:channel)).to include("/chat/user-tracking-state/#{current_user.id}")
    end
  end
end
