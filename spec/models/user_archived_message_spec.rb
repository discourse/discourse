# frozen_string_literal: true

require 'rails_helper'

describe UserArchivedMessage do
  fab!(:user) { Fabricate(:user) }
  fab!(:user_2) { Fabricate(:user) }

  fab!(:private_message) do
    create_post(
      user: user,
      skip_validations: true,
      target_usernames: [user_2.username, user.username].join(","),
      archetype: Archetype.private_message
    ).topic
  end

  describe '.move_to_inbox!' do
    it 'moves topic back to inbox correctly' do
      UserArchivedMessage.archive!(user.id, private_message)

      expect do
        messages = MessageBus.track_publish(PrivateMessageTopicTrackingState.user_channel(user.id)) do
          UserArchivedMessage.move_to_inbox!(user.id, private_message)
        end

        expect(messages.present?).to eq(true)
      end.to change { private_message.message_archived?(user) }.from(true).to(false)
    end

    it 'does not move archived muted messages back to inbox' do
      UserArchivedMessage.archive!(user.id, private_message)

      expect(private_message.message_archived?(user)).to eq(true)

      TopicUser.change(user.id, private_message.id, notification_level: TopicUser.notification_levels[:muted])
      UserArchivedMessage.move_to_inbox!(user.id, private_message)

      expect(private_message.message_archived?(user)).to eq(true)
    end
  end

  describe '.archive' do
    it 'archives message correctly' do
      messages = MessageBus.track_publish(PrivateMessageTopicTrackingState.user_channel(user.id)) do
        UserArchivedMessage.archive!(user.id, private_message)
      end

      expect(messages.present?).to eq(true)
    end
  end

end
