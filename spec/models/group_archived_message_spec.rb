# frozen_string_literal: true

RSpec.describe GroupArchivedMessage do
  fab!(:user)
  fab!(:user_2, :user)

  fab!(:group) do
    Fabricate(:group, messageable_level: Group::ALIAS_LEVELS[:everyone]).tap { |g| g.add(user_2) }
  end
  fab!(:unrelated_group, :group)
  fab!(:public_topic) { Fabricate(:topic, allowed_groups: [unrelated_group]) }

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

    it "does nothing for topics outside the group's private message inbox" do
      [group_message, public_topic].each do |invalid_topic|
        described_class.create!(group: unrelated_group, topic: invalid_topic)
        events = nil
        messages = nil

        expect do
          events =
            DiscourseEvent.track_events(:move_to_inbox) do
              messages =
                MessageBus.track_publish do
                  described_class.move_to_inbox!(unrelated_group.id, invalid_topic)
                end
            end
        end.to not_change {
          described_class.where(group: unrelated_group, topic: invalid_topic).count
        }.and not_change { Jobs::GroupPmUpdateSummary.jobs.size }

        expect(events).to be_empty
        expect(messages).to be_empty
      end
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

    it "does nothing for topics outside the group's private message inbox" do
      [group_message, public_topic].each do |invalid_topic|
        events = nil
        messages = nil

        expect do
          events =
            DiscourseEvent.track_events(:archive_message) do
              messages =
                MessageBus.track_publish do
                  described_class.archive!(unrelated_group.id, invalid_topic)
                end
            end
        end.to not_change {
          described_class.where(group: unrelated_group, topic: invalid_topic).count
        }.and not_change { Jobs::GroupPmUpdateSummary.jobs.size }

        expect(events).to be_empty
        expect(messages).to be_empty
      end
    end
  end
end
