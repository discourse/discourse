# frozen_string_literal: true

# This class is used to mirror unread and new status for private messages between
# server and client.
#
# On the server side, this class has two main responsibilities. The first is to
# query the database for the initial state of a user's unread and new private
# messages. The second is to publish message_bus messages to notify the client
# of various topic events.
#
# On the client side, we have a `PrivateMessageTopicTrackingState` class as well
# which will load the initial state into memory and subscribes to the relevant
# message_bus messages. When a message is received, it modifies the in-memory
# state based on the message type. The filtering for new and unread topics is
# done on the client side based on the in-memory state in order to derive the
# count of new and unread topics efficiently.
class PrivateMessageTopicTrackingState
  CHANNEL_PREFIX = "/private-message-topic-tracking-state"
  NEW_MESSAGE_TYPE = "new_topic"
  UNREAD_MESSAGE_TYPE = "unread"
  ARCHIVE_MESSAGE_TYPE = "archive"
  GROUP_ARCHIVE_MESSAGE_TYPE = "group_archive"

  def self.report(user)
    sql = new_and_unread_sql(user)

    DB.query(
      sql + "\n\n LIMIT :max_topics",
      {
        max_topics: TopicTrackingState::MAX_TOPICS,
        min_date: Time.at(SiteSetting.min_new_topics_time).to_datetime
      }
    )
  end

  def self.new_and_unread_sql(user)
    sql = report_raw_sql(user, skip_unread: true)
    sql << "\nUNION ALL\n\n"
    sql << report_raw_sql(user, skip_new: true)
  end

  def self.report_raw_sql(user, skip_unread: false,
                                skip_new: false)

    unread =
      if skip_unread
        "1=0"
      else
        TopicQuery.unread_filter(Topic, staff: user.staff?).where_clause.ast.to_sql
      end

    new =
      if skip_new
        "1=0"
      else
        new_filter_sql
      end

    sql = +<<~SQL
      SELECT
        DISTINCT topics.id AS topic_id,
        u.id AS user_id,
        last_read_post_number,
        tu.notification_level,
        #{highest_post_number_column_select(user.staff?)},
        ARRAY(SELECT group_id FROM topic_allowed_groups WHERE topic_allowed_groups.topic_id = topics.id) AS group_ids
      FROM topics
      JOIN users u on u.id = #{user.id.to_i}
      JOIN user_stats AS us ON us.user_id = u.id
      JOIN user_options AS uo ON uo.user_id = u.id
      LEFT JOIN group_users gu ON gu.user_id = u.id
      LEFT JOIN topic_allowed_groups tag ON tag.topic_id = topics.id AND tag.group_id = gu.group_id
      LEFT JOIN topic_users tu ON tu.topic_id = topics.id AND tu.user_id = u.id
      LEFT JOIN topic_allowed_users tau ON tau.topic_id = topics.id AND tau.user_id = u.id
      #{skip_new ? "" : "LEFT JOIN dismissed_topic_users ON dismissed_topic_users.topic_id = topics.id AND dismissed_topic_users.user_id = #{user.id.to_i}"}
      WHERE (tau.topic_id IS NOT NULL OR tag.topic_id IS NOT NULL) AND
        #{skip_unread ? "" : "topics.updated_at >= LEAST(us.first_unread_pm_at, gu.first_unread_pm_at) AND"}
        topics.archetype = 'private_message' AND
        ((#{unread}) OR (#{new})) AND
        topics.deleted_at IS NULL
    SQL
  end

  def self.highest_post_number_column_select(staff)
    "#{staff ? "topics.highest_staff_post_number AS highest_post_number" : "topics.highest_post_number"}"
  end

  def self.publish_unread(post)
    return unless post.topic.private_message?

    scope = TopicUser
      .tracking(post.topic_id)
      .includes(user: :user_stat)

    allowed_group_ids = post.topic.allowed_groups.pluck(:id)

    group_ids =
      if post.post_type == Post.types[:whisper]
        [Group::AUTO_GROUPS[:staff]]
      else
        allowed_group_ids
      end

    if group_ids.present?
      scope = scope
        .joins("INNER JOIN group_users gu ON gu.user_id = topic_users.user_id")
        .where("gu.group_id IN (?)", group_ids)
    end

    scope
      .select([:user_id, :last_read_post_number, :notification_level])
      .each do |tu|

      message = {
        topic_id: post.topic_id,
        message_type: UNREAD_MESSAGE_TYPE,
        payload: {
          last_read_post_number: tu.last_read_post_number,
          highest_post_number: post.post_number,
          notification_level: tu.notification_level,
          group_ids: allowed_group_ids
        }
      }

      MessageBus.publish(self.channel(tu.user_id), message.as_json,
        user_ids: [tu.user_id]
      )
    end
  end

  def self.publish_new(topic)
    return unless topic.private_message?

    message = {
      message_type: NEW_MESSAGE_TYPE,
      topic_id: topic.id,
      payload: {
        last_read_post_number: nil,
        highest_post_number: 1,
        group_ids: topic.allowed_groups.pluck(:id)
      }
    }.as_json

    topic.all_allowed_users.pluck(:id).each do |user_id|
      MessageBus.publish(self.channel(user_id), message, user_ids: [user_id])
    end
  end

  def self.publish_group_archived(topic, group_id)
    return unless topic.private_message?

    message = {
      message_type: GROUP_ARCHIVE_MESSAGE_TYPE,
      topic_id: topic.id,
      payload: {
        group_ids: [group_id]
      }
    }.as_json

    topic
      .allowed_group_users
      .where("group_users.group_id = ?", group_id)
      .pluck(:id)
      .each do |user_id|

      MessageBus.publish(self.channel(user_id), message, user_ids: [user_id])
    end
  end

  def self.publish_user_archived(topic, user_id)
    return unless topic.private_message?

    message = {
      message_type: ARCHIVE_MESSAGE_TYPE,
      topic_id: topic.id,
    }.as_json

    MessageBus.publish(self.channel(user_id), message, user_ids: [user_id])
  end

  def self.new_filter_sql
    TopicQuery.new_filter(
      Topic, treat_as_new_topic_clause_sql: treat_as_new_topic_clause
    ).where_clause.ast.to_sql +
      " AND topics.created_at > :min_date" +
      " AND dismissed_topic_users.id IS NULL"
  end

  def self.treat_as_new_topic_clause
    User.where(
      "GREATEST(CASE
        WHEN COALESCE(uo.new_topic_duration_minutes, :default_duration) = :always THEN u.created_at
        WHEN COALESCE(uo.new_topic_duration_minutes, :default_duration) = :last_visit THEN COALESCE(u.previous_visit_at,u.created_at)
        ELSE (:now::timestamp - INTERVAL '1 MINUTE' * COALESCE(uo.new_topic_duration_minutes, :default_duration))
      END, u.created_at, :min_date)",
      {
        now: DateTime.now,
        last_visit: User::NewTopicDuration::LAST_VISIT,
        always: User::NewTopicDuration::ALWAYS,
        default_duration: SiteSetting.default_other_new_topic_duration_minutes,
        min_date: Time.at(SiteSetting.min_new_topics_time).to_datetime
      }
    ).where_clause.ast.to_sql
  end

  def self.channel(user_id)
    "#{CHANNEL_PREFIX}/#{user_id}"
  end
end
