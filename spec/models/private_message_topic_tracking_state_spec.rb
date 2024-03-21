# frozen_string_literal: true

RSpec.describe PrivateMessageTopicTrackingState do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:user_2) { Fabricate(:user) }

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

  fab!(:private_message) do
    create_post(
      user: user,
      target_usernames: [user_2.username],
      archetype: Archetype.private_message,
    ).topic
  end

  fab!(:private_message_2) do
    create_post(
      user: user,
      target_usernames: [Fabricate(:user).username],
      archetype: Archetype.private_message,
    ).topic
  end

  describe ".report" do
    it "returns the right tracking state" do
      TopicUser.find_by(user: user_2, topic: group_message).update!(last_read_post_number: 1)

      expect(described_class.report(user_2).map(&:topic_id)).to contain_exactly(private_message.id)

      create_post(user: user, topic: group_message)

      report = described_class.report(user_2)

      expect(report.map(&:topic_id)).to contain_exactly(group_message.id, private_message.id)

      state = report.first

      expect(state.topic_id).to eq(private_message.id)
      expect(state.user_id).to eq(user_2.id)
      expect(state.last_read_post_number).to eq(nil)
      expect(state.notification_level).to eq(NotificationLevels.all[:watching])
      expect(state.highest_post_number).to eq(1)
      expect(state.group_ids).to eq([])

      expect(report.last.group_ids).to contain_exactly(group.id)
    end

    it "returns the right tracking state when topics contain whispers" do
      SiteSetting.whispers_allowed_groups = "#{Group::AUTO_GROUPS[:staff]}"
      TopicUser.find_by(user: user_2, topic: private_message).update!(last_read_post_number: 1)

      create_post(
        raw: "this is a test post",
        topic: private_message,
        post_type: Post.types[:whisper],
        user: Fabricate(:admin),
      )

      expect(described_class.report(user_2).map(&:topic_id)).to contain_exactly(group_message.id)

      user_2.grant_admin!

      tracking_state = described_class.report(user_2)

      expect(
        tracking_state.map { |topic| [topic.topic_id, topic.highest_post_number] },
      ).to contain_exactly([group_message.id, 1], [private_message.id, 2])
    end

    it "returns the right tracking state when topics have been dismissed" do
      DismissedTopicUser.create!(user_id: user_2.id, topic_id: group_message.id)

      expect(described_class.report(user_2).map(&:topic_id)).to contain_exactly(private_message.id)
    end
  end

  describe ".publish_new" do
    it "should publish the right message_bus message" do
      messages = MessageBus.track_publish { described_class.publish_new(private_message) }

      expect(messages.map(&:channel)).to contain_exactly(described_class.user_channel(user_2.id))

      data = messages.first.data

      expect(data["message_type"]).to eq(described_class::NEW_MESSAGE_TYPE)
      expect(data["topic_id"]).to eq(private_message.id)
      expect(data["payload"]["last_read_post_number"]).to eq(nil)
      expect(data["payload"]["highest_post_number"]).to eq(1)
      expect(data["payload"]["group_ids"]).to eq([])
      expect(data["payload"]["created_by_user_id"]).to eq(private_message.user_id)
    end

    it "should publish the right message_bus message for a group message" do
      messages = MessageBus.track_publish { described_class.publish_new(group_message) }

      expect(messages.map(&:channel)).to contain_exactly(described_class.group_channel(group.id))

      data = messages.first.data

      expect(data["message_type"]).to eq(described_class::NEW_MESSAGE_TYPE)
      expect(data["topic_id"]).to eq(group_message.id)
      expect(data["payload"]["last_read_post_number"]).to eq(nil)
      expect(data["payload"]["highest_post_number"]).to eq(1)
      expect(data["payload"]["group_ids"]).to eq([group.id])
      expect(data["payload"]["created_by_user_id"]).to eq(group_message.user_id)
    end
  end

  describe ".publish_unread" do
    it "should publish the right message_bus message" do
      messages =
        MessageBus.track_publish { described_class.publish_unread(private_message.first_post) }

      expect(messages.map(&:channel)).to contain_exactly(described_class.user_channel(user_2.id))

      data = messages.first.data

      expect(data["message_type"]).to eq(described_class::UNREAD_MESSAGE_TYPE)
      expect(data["topic_id"]).to eq(private_message.id)
      expect(data["payload"]["last_read_post_number"]).to eq(nil)
      expect(data["payload"]["highest_post_number"]).to eq(1)
      expect(data["payload"]["created_by_user_id"]).to eq(private_message.first_post.user_id)
      expect(data["payload"]["notification_level"]).to eq(NotificationLevels.all[:watching])
      expect(data["payload"]["group_ids"]).to eq([])
    end

    it "does not publish message_bus message if post in topic is not new for user" do
      group_message.update!(created_at: 3.days.ago)
      user_2.user_option.update!(new_topic_duration_minutes: 2.days.minutes)

      messages =
        MessageBus.track_publish { described_class.publish_unread(group_message.first_post) }

      expect(messages).to eq([])
    end
  end

  describe ".publish_group_archived" do
    it "should publish the right message_bus message" do
      user_3 = Fabricate(:user)
      group.add(user_3)

      messages =
        MessageBus.track_publish do
          described_class.publish_group_archived(
            topic: group_message,
            group_id: group.id,
            acting_user_id: user_3.id,
          )
        end

      expect(messages.map(&:channel)).to contain_exactly(described_class.group_channel(group.id))

      data =
        messages.find { |message| message.channel == described_class.group_channel(group.id) }.data

      expect(data["message_type"]).to eq(described_class::GROUP_ARCHIVE_MESSAGE_TYPE)
      expect(data["topic_id"]).to eq(group_message.id)
      expect(data["payload"]["group_ids"]).to contain_exactly(group.id)
      expect(data["payload"]["acting_user_id"]).to eq(user_3.id)
    end
  end

  describe ".publish_read" do
    it "should publish the right message_bus message" do
      message =
        MessageBus
          .track_publish(described_class.user_channel(user.id)) do
            PrivateMessageTopicTrackingState.publish_read(private_message.id, 1, user)
          end
          .first

      data = message.data

      expect(message.user_ids).to contain_exactly(user.id)
      expect(message.group_ids).to eq(nil)
      expect(data["topic_id"]).to eq(private_message.id)
      expect(data["message_type"]).to eq(described_class::READ_MESSAGE_TYPE)
      expect(data["payload"]["last_read_post_number"]).to eq(1)
      expect(data["payload"]["highest_post_number"]).to eq(1)
      expect(data["payload"]["notification_level"]).to eq(nil)
    end
  end
end
