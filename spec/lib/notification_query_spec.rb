# frozen_string_literal: true

RSpec.describe NotificationQuery do
  fab!(:user)
  fab!(:user2, :user)

  def notification_query(user: nil, guardian: nil)
    NotificationQuery.new(user: user || self.user, guardian:)
  end

  describe "#list" do
    it "returns notifications for the user" do
      notification = Fabricate(:notification, user:)
      expect(notification_query.list).to include(notification)
    end

    it "does not return notifications for other users" do
      notification = Fabricate(:notification, user: user2)
      expect(notification_query.list).not_to include(notification)
    end

    it "includes notifications without topic_id" do
      notification =
        Fabricate(
          :notification,
          user:,
          topic: nil,
          notification_type: Notification.types[:chat_mention],
        )
      expect(notification_query.list).to include(notification)
    end

    it "includes notifications for accessible public topics" do
      topic = Fabricate(:topic)
      notification = Fabricate(:notification, user:, topic:)
      expect(notification_query.list).to include(notification)
    end

    it "includes notifications for accessible restricted category topics" do
      group = Fabricate(:group)
      group.add(user)
      category = Fabricate(:private_category, group:)
      topic = Fabricate(:topic, category:)
      notification = Fabricate(:notification, user:, topic:)

      expect(notification_query.list).to include(notification)
    end

    it "includes notifications for PMs user is directly allowed on" do
      pm = Fabricate(:private_message_topic, user:)
      notification = Fabricate(:notification, user:, topic: pm)

      expect(notification_query.list).to include(notification)
    end

    it "includes notifications for PMs via group membership" do
      group = Fabricate(:group)
      group.add(user)
      pm = Fabricate(:private_message_topic)
      pm.allowed_groups << group
      notification = Fabricate(:notification, user:, topic: pm)

      expect(notification_query.list).to include(notification)
    end

    it "excludes notifications for soft-deleted topics for regular users" do
      topic = Fabricate(:topic)
      notification = Fabricate(:notification, user:, topic:)
      topic.trash!

      expect(notification_query.list).not_to include(notification)
    end

    it "includes notifications for soft-deleted topics for staff" do
      user.update!(admin: true)
      topic = Fabricate(:topic)
      notification = Fabricate(:notification, user:, topic:)
      topic.trash!

      expect(notification_query.list).to include(notification)
    end

    it "excludes notifications for hard-deleted topics" do
      topic = Fabricate(:topic)
      notification = Fabricate(:notification, user:, topic:)
      topic_id = topic.id
      topic.destroy!

      notification.reload
      expect(notification.topic_id).to eq(topic_id)
      expect(notification_query.list).not_to include(notification)
    end

    it "excludes notifications for inaccessible category topics" do
      group = Fabricate(:group)
      category = Fabricate(:private_category, group:)
      topic = Fabricate(:topic, category:)
      notification = Fabricate(:notification, user:, topic:)

      expect(notification_query.list).not_to include(notification)
    end

    it "excludes notifications for shared draft topics when user cannot see shared drafts" do
      category = Fabricate(:category)
      SiteSetting.shared_drafts_category = category.id
      topic = Fabricate(:topic, category:)
      Fabricate(:shared_draft, topic:, category: Fabricate(:category))
      notification = Fabricate(:notification, user:, topic:)

      expect(notification_query.list).not_to include(notification)
    end

    it "includes notifications for shared draft topics when user can see shared drafts" do
      group = Fabricate(:group)
      group.add(user)
      SiteSetting.shared_drafts_allowed_groups = group.id.to_s

      category = Fabricate(:category)
      SiteSetting.shared_drafts_category = category.id
      topic = Fabricate(:topic, category:)
      Fabricate(:shared_draft, topic:, category: Fabricate(:category))
      notification = Fabricate(:notification, user:, topic:)

      expect(notification_query.list).to include(notification)
    end

    it "excludes notifications for inaccessible PMs" do
      pm = Fabricate(:private_message_topic, user: user2)
      notification = Fabricate(:notification, user:, topic: pm)

      expect(notification_query.list).not_to include(notification)
    end

    it "respects the filter parameter for unread" do
      read_notification = Fabricate(:notification, user:, read: true)
      unread_notification = Fabricate(:notification, user:, read: false)

      result = notification_query.list(filter: :unread)
      expect(result).not_to include(read_notification)
      expect(result).to include(unread_notification)
    end

    it "respects the filter parameter for read" do
      read_notification = Fabricate(:notification, user:, read: true)
      unread_notification = Fabricate(:notification, user:, read: false)

      result = notification_query.list(filter: :read)
      expect(result).to include(read_notification)
      expect(result).not_to include(unread_notification)
    end

    it "respects the types parameter" do
      mention = Fabricate(:notification, user:, notification_type: Notification.types[:mentioned])
      reply = Fabricate(:notification, user:, notification_type: Notification.types[:replied])

      result = notification_query.list(types: [Notification.types[:mentioned]])
      expect(result).to include(mention)
      expect(result).not_to include(reply)
    end

    it "respects limit and offset" do
      notifications = 5.times.map { Fabricate(:notification, user:) }

      result = notification_query.list(limit: 2, offset: 1, order: :desc)
      expect(result.length).to eq(2)
    end

    context "with badge notifications" do
      fab!(:enabled_badge) { Fabricate(:badge, enabled: true) }
      fab!(:disabled_badge) { Fabricate(:badge, enabled: false) }

      fab!(:enabled_badge_notification) do
        Fabricate(
          :notification,
          user:,
          notification_type: Notification.types[:granted_badge],
          data: { badge_id: enabled_badge.id, badge_name: enabled_badge.name }.to_json,
        )
      end

      fab!(:disabled_badge_notification) do
        Fabricate(
          :notification,
          user:,
          notification_type: Notification.types[:granted_badge],
          data: { badge_id: disabled_badge.id, badge_name: disabled_badge.name }.to_json,
        )
      end

      fab!(:regular_notification) { Fabricate(:notification, user:) }

      it "excludes all badge notifications when enable_badges is false" do
        SiteSetting.enable_badges = false

        result = notification_query.list
        expect(result).to include(regular_notification)
        expect(result).not_to include(enabled_badge_notification)
        expect(result).not_to include(disabled_badge_notification)
      end

      it "excludes badge notifications for disabled badges" do
        result = notification_query.list
        expect(result).to include(regular_notification)
        expect(result).to include(enabled_badge_notification)
        expect(result).not_to include(disabled_badge_notification)
      end

      it "excludes badge notifications for deleted badges" do
        enabled_badge.destroy!

        result = notification_query.list
        expect(result).to include(regular_notification)
        expect(result).not_to include(enabled_badge_notification)
      end
    end
  end

  describe "#grouped_unread_counts" do
    it "returns counts by notification type" do
      Fabricate(
        :notification,
        user:,
        notification_type: Notification.types[:mentioned],
        read: false,
      )
      Fabricate(
        :notification,
        user:,
        notification_type: Notification.types[:mentioned],
        read: false,
      )
      Fabricate(:notification, user:, notification_type: Notification.types[:replied], read: false)

      result = notification_query.grouped_unread_counts
      expect(result[Notification.types[:mentioned]]).to eq(2)
      expect(result[Notification.types[:replied]]).to eq(1)
    end

    it "does not count read notifications" do
      Fabricate(:notification, user:, notification_type: Notification.types[:mentioned], read: true)

      result = notification_query.grouped_unread_counts
      expect(result[Notification.types[:mentioned]]).to be_nil
    end

    it "respects topic visibility" do
      group = Fabricate(:group)
      category = Fabricate(:private_category, group:)
      topic = Fabricate(:topic, category:)
      Fabricate(
        :notification,
        user:,
        topic:,
        notification_type: Notification.types[:mentioned],
        read: false,
      )

      result = notification_query.grouped_unread_counts
      expect(result[Notification.types[:mentioned]]).to be_nil
    end
  end

  describe "#unread_count" do
    it "counts unread notifications" do
      Fabricate(:notification, user:, read: false)
      Fabricate(:notification, user:, read: false)
      Fabricate(:notification, user:, read: true)

      expect(notification_query.unread_count).to eq(2)
    end

    it "respects seen_notification_id" do
      old_notification = Fabricate(:notification, user:, read: false)
      user.update!(seen_notification_id: old_notification.id)
      new_notification = Fabricate(:notification, user:, read: false)

      expect(notification_query.unread_count).to eq(1)
    end

    it "excludes notifications for inaccessible topics" do
      group = Fabricate(:group)
      category = Fabricate(:private_category, group:)
      topic = Fabricate(:topic, category:)
      Fabricate(:notification, user:, topic:, read: false)

      expect(notification_query.unread_count).to eq(0)
    end
  end

  describe "#unread_high_priority_count" do
    it "counts only high priority unread notifications" do
      Fabricate(:notification, user:, read: false, high_priority: true)
      Fabricate(:notification, user:, read: false, high_priority: false)

      expect(notification_query.unread_high_priority_count).to eq(1)
    end
  end

  describe "#unread_low_priority_count" do
    it "counts only low priority unread notifications" do
      Fabricate(:notification, user:, read: false, high_priority: true)
      Fabricate(:notification, user:, read: false, high_priority: false)

      expect(notification_query.unread_low_priority_count).to eq(1)
    end
  end

  describe "#unread_count_for_type" do
    it "counts unread notifications of a specific type" do
      Fabricate(
        :notification,
        user:,
        notification_type: Notification.types[:mentioned],
        read: false,
      )
      Fabricate(:notification, user:, notification_type: Notification.types[:replied], read: false)

      expect(notification_query.unread_count_for_type(Notification.types[:mentioned])).to eq(1)
    end

    it "respects the since parameter" do
      Fabricate(
        :notification,
        user:,
        notification_type: Notification.types[:mentioned],
        read: false,
        created_at: 2.days.ago,
      )
      Fabricate(
        :notification,
        user:,
        notification_type: Notification.types[:mentioned],
        read: false,
        created_at: 1.hour.ago,
      )

      expect(
        notification_query.unread_count_for_type(Notification.types[:mentioned], since: 1.day.ago),
      ).to eq(1)
    end
  end

  describe "#new_personal_messages_count" do
    it "counts new PM notifications" do
      Fabricate(
        :notification,
        user:,
        notification_type: Notification.types[:private_message],
        read: false,
      )
      Fabricate(
        :notification,
        user:,
        notification_type: Notification.types[:mentioned],
        read: false,
      )

      expect(notification_query.new_personal_messages_count).to eq(1)
    end
  end

  describe "#total_count" do
    it "counts total notifications" do
      Fabricate(:notification, user:, read: true)
      Fabricate(:notification, user:, read: false)

      expect(notification_query.total_count).to eq(2)
    end

    it "respects filter parameter" do
      Fabricate(:notification, user:, read: true)
      Fabricate(:notification, user:, read: false)

      expect(notification_query.total_count(filter: :unread)).to eq(1)
      expect(notification_query.total_count(filter: :read)).to eq(1)
    end
  end

  describe "#list with prioritized: true" do
    it "returns notifications prioritized by high_priority and read status" do
      Fabricate(:notification, user:, high_priority: false, read: true)
      Fabricate(:notification, user:, high_priority: false, read: false)
      Fabricate(:notification, user:, high_priority: true, read: true)
      high_unread = Fabricate(:notification, user:, high_priority: true, read: false)

      expect(notification_query.list(prioritized: true).first).to eq(high_unread)
    end

    it "excludes like notifications when user has likes disabled and no types filter" do
      user.user_option.update!(
        like_notification_frequency: UserOption.like_notification_frequency_type[:never],
      )
      like_notification =
        Fabricate(:notification, user:, notification_type: Notification.types[:liked])
      regular_notification = Fabricate(:notification, user:)

      result = notification_query.list(prioritized: true)
      expect(result).to include(regular_notification)
      expect(result).not_to include(like_notification)
    end

    it "includes like notifications when filtering by specific types" do
      user.user_option.update!(
        like_notification_frequency: UserOption.like_notification_frequency_type[:never],
      )
      like_notification =
        Fabricate(:notification, user:, notification_type: Notification.types[:liked])

      result = notification_query.list(prioritized: true, types: [Notification.types[:liked]])
      expect(result).to include(like_notification)
    end
  end

  describe "#max_id" do
    it "returns the max notification id" do
      n1 = Fabricate(:notification, user:)
      n2 = Fabricate(:notification, user:)

      expect(notification_query.max_id).to eq(n2.id)
    end

    it "returns the max id after the given since_id" do
      n1 = Fabricate(:notification, user:)
      n2 = Fabricate(:notification, user:)

      expect(notification_query.max_id(since_id: n1.id)).to eq(n2.id)
    end

    it "returns nil when there are no notifications after since_id" do
      n1 = Fabricate(:notification, user:)

      expect(notification_query.max_id(since_id: n1.id)).to be_nil
    end

    it "excludes notifications for inaccessible topics" do
      group = Fabricate(:group)
      category = Fabricate(:private_category, group:)
      topic = Fabricate(:topic, category:)
      Fabricate(:notification, user:, topic:)

      expect(notification_query.max_id).to be_nil
    end
  end

  describe "#recent_ids_with_read_status" do
    it "returns recent notification ids with read status" do
      read = Fabricate(:notification, user:, read: true, high_priority: false)
      unread = Fabricate(:notification, user:, read: false, high_priority: false)

      result = notification_query.recent_ids_with_read_status
      expect(result).to include([read.id, true])
      expect(result).to include([unread.id, false])
    end

    it "excludes notifications for inaccessible topics" do
      group = Fabricate(:group)
      category = Fabricate(:private_category, group:)
      topic = Fabricate(:topic, category:)
      Fabricate(:notification, user:, topic:, read: false)

      expect(notification_query.recent_ids_with_read_status).to be_empty
    end
  end
end
