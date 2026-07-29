# frozen_string_literal: true

module PendingAssignsReminderSpecHelpers
  def assert_reminder_not_created
    expect { reminder.remind(user) }.not_to change { Post.count }
  end
end

module AssignmentPublishSpecHelpers
  def assert_publish_topic_state(topic, user: nil, group: nil)
    messages = MessageBus.track_publish { yield }

    message = messages.find { |published_message| published_message.channel == channel }

    expect(message.data[:topic_id]).to eq(topic.id)
    expect(message.user_ids).to eq([user.id]) if user
    expect(message.group_ids).to eq([group.id]) if group
  end
end

module TopicsBulkAssignSpecHelpers
  def bulk_assign(operation, ids: [topic1.id, topic2.id])
    put "/topics/bulk.json", params: { topic_ids: ids, operation: operation }
  end
end

module AssignControllerSpecHelpers
  def assign_user_to_post
    assignee = Fabricate(:user, groups: [allowed_group])
    Fabricate(:post_assignment, assigned_to: assignee, assigned_by_user: admin)
    assignee
  end
end

module TopicQueryAssignSpecHelpers
  def assign_to(topic:, user:, assignee:)
    topic.tap { |assigned_topic| Assigner.new(assigned_topic, user).assign(assignee) }
  end
end
