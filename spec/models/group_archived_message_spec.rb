# frozen_string_literal: true

RSpec.describe GroupArchivedMessage do
  fab!(:user) { Fabricate(:user) }
  fab!(:user_2) { Fabricate(:user) }

  before_all { Group.refresh_automatic_groups! }

  fab!(:group) do
    Fabricate(:group, messageable_level: Group::ALIAS_LEVELS[:everyone]).tap { |g| g.add(user_2) }
  end

  fab!(:group_message) do
    create_post(
      user: user,
      target_group_names: [group.name],
      archetype: Archetype.private_message,
    ).topic
  end

  describe ".move_to_inbox!" do
    it "should unarchive the topic correctly" do
      described_class.archive!(group.id, group_message)

      messages =
        MessageBus.track_publish(PrivateMessageTopicTrackingState.group_channel(group.id)) do
          described_class.move_to_inbox!(group.id, group_message)
        end

      expect(messages.present?).to eq(true)

      expect(GroupArchivedMessage.exists?(topic: group_message, group: group)).to eq(false)
    end
  end

  describe ".archive!" do
    it "should archive the topic correctly" do
      messages =
        MessageBus.track_publish(PrivateMessageTopicTrackingState.group_channel(group.id)) do
          described_class.archive!(group.id, group_message)
        end

      expect(GroupArchivedMessage.exists?(topic: group_message, group: group)).to eq(true)

      expect(messages.present?).to eq(true)
    end
  end
end
