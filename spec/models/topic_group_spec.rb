# frozen_string_literal: true

require 'rails_helper'

describe TopicGroup do
  describe '#update_last_read' do
    fab!(:group) { Fabricate(:group) }
    fab!(:user) { Fabricate(:user) }

    before do
      @topic = Fabricate(:private_message_topic, allowed_groups: [group])
      group.add(user)
    end

    it 'does nothing if the user is not a member of an allowed group' do
      another_user = Fabricate(:user)

      described_class.update_last_read(another_user, @topic.id, @topic.highest_post_number)
      created_topic_group = described_class.where(topic: @topic, group: group).exists?

      expect(created_topic_group).to eq(false)
    end

    it 'creates a new record if the user is a member of an allowed group' do
      described_class.update_last_read(user, @topic.id, @topic.highest_post_number)
      created_topic_group = described_class.find_by(topic: @topic, group: group)

      expect(created_topic_group.last_read_post_number).to eq @topic.highest_post_number
    end

    it 'does nothing if the topic does not have allowed groups' do
      @topic.update!(allowed_groups: [])

      described_class.update_last_read(user, @topic.id, @topic.highest_post_number)
      created_topic_group = described_class.where(topic: @topic, group: group).exists?

      expect(created_topic_group).to eq(false)
    end

    it 'updates an existing record with a higher post number' do
      described_class.create!(topic: @topic, group: group, last_read_post_number: @topic.highest_post_number - 1)

      described_class.update_last_read(user, @topic.id, @topic.highest_post_number)
      created_topic_group = described_class.find_by(topic: @topic, group: group)

      expect(created_topic_group.last_read_post_number).to eq @topic.highest_post_number
    end

    it 'does nothing if the user read post number is lower than the current one' do
      highest_read_number = @topic.highest_post_number + 1
      described_class.create!(topic: @topic, group: group, last_read_post_number: highest_read_number)

      described_class.update_last_read(user, @topic.id, @topic.highest_post_number)
      created_topic_group = described_class.find_by(topic: @topic, group: group)

      expect(created_topic_group.last_read_post_number).to eq highest_read_number
    end

    it 'creates a new record if the list of allowed groups has changed' do
      another_allowed_group = Fabricate(:group)
      another_allowed_group.add(user)
      @topic.allowed_groups << another_allowed_group
      described_class.create!(topic: @topic, group: group, last_read_post_number: @topic.highest_post_number)

      described_class.update_last_read(user, @topic.id, @topic.highest_post_number)
      created_topic_group = described_class.find_by(topic: @topic, group: another_allowed_group)

      expect(created_topic_group.last_read_post_number).to eq @topic.highest_post_number
    end

    it 'Only updates the record that shares the same topic_id' do
      new_post_number = 100
      topic2 = Fabricate(:private_message_topic, allowed_groups: [group], topic_allowed_users: [])
      described_class.create!(topic: @topic, group: group, last_read_post_number: @topic.highest_post_number)
      described_class.create!(topic: topic2, group: group, last_read_post_number: topic2.highest_post_number)

      described_class.update_last_read(user, @topic.id, new_post_number)
      created_topic_group = described_class.find_by(topic: @topic, group: group)
      created_topic_group2 = described_class.find_by(topic: topic2, group: group)

      expect(created_topic_group.last_read_post_number).to eq new_post_number
      expect(created_topic_group2.last_read_post_number).to eq topic2.highest_post_number
    end

    it "will not raise an error if a topic group already exists" do
      TopicGroup.create_topic_group(user, @topic.id, 3, [])
      expect(TopicGroup.find_by(group: group, topic: @topic).last_read_post_number).to eq(3)
      TopicGroup.create_topic_group(user, @topic.id, 10, [])
      expect(TopicGroup.find_by(group: group, topic: @topic).last_read_post_number).to eq(10)
    end
  end
end
