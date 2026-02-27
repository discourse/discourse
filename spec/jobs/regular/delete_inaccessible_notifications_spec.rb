# frozen_string_literal: true

RSpec.describe Jobs::DeleteInaccessibleNotifications do
  fab!(:user)

  describe "topic_id mode" do
    it "deletes notifications for users who cannot see the topic" do
      group = Fabricate(:group)
      category = Fabricate(:private_category, group:)
      topic = Fabricate(:topic, category:)
      notification = Fabricate(:notification, user:, topic:)

      described_class.new.execute(topic_id: topic.id)

      expect(Notification.exists?(notification.id)).to eq(false)
    end

    it "preserves notifications for users who can see the topic" do
      topic = Fabricate(:topic)
      notification = Fabricate(:notification, user:, topic:)

      described_class.new.execute(topic_id: topic.id)

      expect(Notification.exists?(notification.id)).to eq(true)
    end

    it "handles PM topics" do
      pm = Fabricate(:private_message_topic, user:)
      notification = Fabricate(:notification, user:, topic: pm)

      described_class.new.execute(topic_id: pm.id)

      expect(Notification.exists?(notification.id)).to eq(true)
    end
  end

  describe "category_id mode" do
    it "cleans up notifications across all topics in the category" do
      group = Fabricate(:group)
      category = Fabricate(:private_category, group:)
      topic1 = Fabricate(:topic, category:)
      topic2 = Fabricate(:topic, category:)
      n1 = Fabricate(:notification, user:, topic: topic1)
      n2 = Fabricate(:notification, user:, topic: topic2)

      described_class.new.execute(category_id: category.id)

      expect(Notification.exists?(n1.id)).to eq(false)
      expect(Notification.exists?(n2.id)).to eq(false)
    end
  end

  describe "user_id + group_id mode" do
    it "deletes notifications for topics the user lost access to via group removal" do
      group = Fabricate(:group)
      category = Fabricate(:private_category, group:)
      topic = Fabricate(:topic, category:)
      notification = Fabricate(:notification, user:, topic:)

      described_class.new.execute(user_id: user.id, group_id: group.id)

      expect(Notification.exists?(notification.id)).to eq(false)
    end

    it "preserves notifications for topics still accessible" do
      group = Fabricate(:group)
      other_group = Fabricate(:group)
      other_group.add(user)
      category = Fabricate(:private_category, group:)
      category.category_groups.create!(
        group: other_group,
        permission_type: CategoryGroup.permission_types[:full],
      )
      topic = Fabricate(:topic, category:)
      notification = Fabricate(:notification, user:, topic:)

      described_class.new.execute(user_id: user.id, group_id: group.id)

      expect(Notification.exists?(notification.id)).to eq(true)
    end

    it "deletes PM notifications when group is removed from PM" do
      group = Fabricate(:group)
      pm = Fabricate(:private_message_topic)
      pm.allowed_groups << group
      notification = Fabricate(:notification, user:, topic: pm)

      described_class.new.execute(user_id: user.id, group_id: group.id)

      expect(Notification.exists?(notification.id)).to eq(false)
    end

    it "does nothing for nonexistent user" do
      expect { described_class.new.execute(user_id: -1, group_id: 1) }.not_to raise_error
    end
  end
end
