# frozen_string_literal: true

require "rails_helper"

RSpec.describe Jobs::UnassignNotification do
  describe "#execute" do
    fab!(:user1) { Fabricate(:user) }
    fab!(:user2) { Fabricate(:user) }
    fab!(:topic)
    fab!(:post) { Fabricate(:post, topic: topic) }
    fab!(:pm_post) { Fabricate(:private_message_post) }
    fab!(:pm) { pm_post.topic }
    fab!(:assign_allowed_group) { Group.find_by(name: "staff") }

    before { assign_allowed_group.add(user1) }

    def assert_publish_topic_state(topic, user)
      message = MessageBus.track_publish("/private-messages/assigned") { yield }.first

      expect(message.data[:topic_id]).to eq(topic.id)
      expect(message.user_ids).to eq([user.id])
    end

    describe "User" do
      fab!(:assignment) { Fabricate(:topic_assignment, topic: topic, assigned_to: user2) }

      before { assignment.create_missing_notifications! }

      it "deletes notifications" do
        expect {
          described_class.new.execute(
            {
              topic_id: topic.id,
              post_id: post.id,
              assigned_to_id: user2.id,
              assigned_to_type: "User",
              assignment_id: assignment.id,
            },
          )
        }.to change { user2.notifications.count }.by(-1)
      end

      it "should publish the right message when private message" do
        user = pm.allowed_users.first
        assign_allowed_group.add(user)

        assert_publish_topic_state(pm, user) do
          described_class.new.execute(
            {
              topic_id: pm.id,
              post_id: pm_post.id,
              assigned_to_id: pm.allowed_users.first.id,
              assigned_to_type: "User",
              assignment_id: 4519,
            },
          )
        end
      end
    end

    describe "Group" do
      fab!(:assign_allowed_group) { Group.find_by(name: "staff") }
      fab!(:user3) { Fabricate(:user) }
      fab!(:group)
      fab!(:assignment) do
        Fabricate(:topic_assignment, topic: topic, assigned_to: group, assigned_by_user: user1)
      end

      before do
        group.add(user2)
        group.add(user3)
        assignment.create_missing_notifications!
      end

      it "deletes notifications" do
        expect {
          described_class.new.execute(
            {
              topic_id: topic.id,
              post_id: post.id,
              assigned_to_id: group.id,
              assigned_to_type: "Group",
              assignment_id: assignment.id,
            },
          )
        }.to change { Notification.count }.by(-2)
      end
    end
  end
end
