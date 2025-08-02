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
  include TopicTrackingStatePublishable

  CHANNEL_PREFIX = "/private-message-topic-tracking-state"
  NEW_MESSAGE_TYPE = "new_topic"
  UNREAD_MESSAGE_TYPE = "unread"
  READ_MESSAGE_TYPE = "read"
  GROUP_ARCHIVE_MESSAGE_TYPE = "group_archive"

  def self.report(user)
    sql = new_and_unread_sql(user)

    DB.query(
      sql + "\n\n LIMIT :max_topics",
      {
        max_topics: TopicTrackingState::MAX_TOPICS,
        min_new_topic_date: Time.at(SiteSetting.min_new_topics_time).to_datetime,
      },
    )
  end

  def self.new_and_unread_sql(user)
    sql = report_raw_sql(user, skip_unread: true)
    sql << "\nUNION ALL\n\n"
    sql << report_raw_sql(user, skip_new: true)
  end

  def self.report_raw_sql(user, skip_unread: false, skip_new: false)
    unread =
      if skip_unread
        "1=0"
      else
        first_unread_pm_at = DB.query_single(<<~SQL, user_id: user.id).first
        SELECT
          LEAST(
            MIN(user_stats.first_unread_pm_at),
            MIN(group_users.first_unread_pm_at)
          )
        FROM group_users
        JOIN groups ON groups.id = group_users.group_id
        JOIN user_stats ON user_stats.user_id = :user_id
        WHERE group_users.user_id = :user_id;
        SQL

        <<~SQL
        #{TopicTrackingState.unread_filter_sql(whisperer: user.whisperer?)}
        #{first_unread_pm_at ? "AND topics.updated_at > '#{first_unread_pm_at}'" : ""}
        SQL
      end

    new =
      if skip_new
        "1=0"
      else
        TopicTrackingState.new_filter_sql
      end

    sql = +<<~SQL
      SELECT
        DISTINCT topics.id AS topic_id,
        u.id AS user_id,
        last_read_post_number,
        tu.notification_level,
        #{TopicTrackingState.highest_post_number_column_select(user.whisperer?)},
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
        topics.archetype = 'private_message' AND
        ((#{unread}) OR (#{new})) AND
        topics.deleted_at IS NULL
    SQL
  end

  def self.publish_unread(post)
    topic = post.topic
    return unless topic.private_message?

    scope = TopicUser.tracking(post.topic_id).includes(user: %i[user_stat user_option])

    allowed_group_ids = topic.allowed_groups.pluck(:id)

    group_ids =
      if post.post_type == Post.types[:whisper]
        [Group::AUTO_GROUPS[:staff]]
      else
        allowed_group_ids
      end

    if group_ids.present?
      scope =
        scope.joins("INNER JOIN group_users gu ON gu.user_id = topic_users.user_id").where(
          "gu.group_id IN (?)",
          group_ids,
        )
    end

    # Note: At some point we may want to make the same performance optimisation
    # here as we did with the other topic tracking state, where we only send
    # one 'unread' update to all users, not a more accurate unread update to
    # each individual user with their own read state.
    #
    # cf. f6c852bf8e7f4dea519425ba87a114f22f52a8f4
    scope
      .select(%i[user_id last_read_post_number notification_level])
      .each do |tu|
        next if tu.user_id == post.user_id # skip post creator

        if tu.last_read_post_number.nil? &&
             topic.created_at < tu.user.user_option.treat_as_new_topic_start_date
          next
        end

        message = {
          topic_id: post.topic_id,
          message_type: UNREAD_MESSAGE_TYPE,
          payload: {
            last_read_post_number: tu.last_read_post_number,
            highest_post_number: post.post_number,
            notification_level: tu.notification_level,
            group_ids: allowed_group_ids,
            created_by_user_id: post.user_id,
          },
        }

        MessageBus.publish(self.user_channel(tu.user_id), message.as_json, user_ids: [tu.user_id])
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
        group_ids: topic.allowed_groups.pluck(:id),
        created_by_user_id: topic.user_id,
      },
    }.as_json

    topic
      .allowed_users
      .pluck(:id)
      .each do |user_id|
        next if user_id == topic.user_id # skip topic creator
        MessageBus.publish(self.user_channel(user_id), message, user_ids: [user_id])
      end

    topic
      .allowed_groups
      .pluck(:id)
      .each do |group_id|
        MessageBus.publish(self.group_channel(group_id), message, group_ids: [group_id])
      end
  end

  def self.publish_group_archived(topic:, group_id:, acting_user_id: nil)
    return unless topic.private_message?

    message = {
      message_type: GROUP_ARCHIVE_MESSAGE_TYPE,
      topic_id: topic.id,
      payload: {
        group_ids: [group_id],
        acting_user_id: acting_user_id,
      },
    }.as_json

    MessageBus.publish(self.group_channel(group_id), message, group_ids: [group_id])
  end

  def self.publish_read(topic_id, last_read_post_number, user, notification_level = nil)
    self.publish_read_message(
      message_type: READ_MESSAGE_TYPE,
      channel_name: self.user_channel(user.id),
      topic_id: topic_id,
      user: user,
      last_read_post_number: last_read_post_number,
      notification_level: notification_level,
    )
  end

  def self.user_channel(user_id)
    "#{CHANNEL_PREFIX}/user/#{user_id}"
  end

  def self.group_channel(group_id)
    "#{CHANNEL_PREFIX}/group/#{group_id}"
  end
end
