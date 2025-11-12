# frozen_string_literal: true

module Migrations::Importer::Steps
  class TopicUsers < ::Migrations::Importer::CopyStep
    NOTIFICATION_LEVELS = TopicUser.notification_levels.values.to_set.freeze
    DEFAULT_NOTIFICATION_LEVEL = TopicUser.notification_levels[:regular]
    NOTIFICATION_REASONS = TopicUser.notification_reasons.values.to_set.freeze
    DEFAULT_NOTIFICATION_REASON = TopicUser.notification_reasons[:user_changed]

    depends_on :topics, :users

    requires_set :existing_topic_users,
                 "SELECT topic_id, user_id FROM topic_users WHERE user_id > 0"

    column_names %i[
                   topic_id
                   user_id
                   cleared_pinned_at
                   first_visited_at
                   last_emailed_post_number
                   last_posted_at
                   last_read_post_number
                   last_visited_at
                   notification_level
                   notifications_changed_at
                   notifications_reason_id
                   total_msecs_viewed
                 ]

    total_rows_query <<~SQL, MappingType::TOPICS, MappingType::USERS
      SELECT COUNT(*)
        FROM topic_users
             JOIN mapped.ids mapped_topic
               ON topic_users.topic_id = mapped_topic.original_id AND mapped_topic.type = ?1
             JOIN mapped.ids mapped_user
               ON topic_users.user_id = mapped_user.original_id AND mapped_user.type = ?2
    SQL

    rows_query <<~SQL, MappingType::TOPICS, MappingType::USERS
      SELECT topic_users.*,
             mapped_topic.discourse_id AS discourse_topic_id,
             mapped_user.discourse_id  AS discourse_user_id
        FROM topic_users
             JOIN mapped.ids mapped_topic
               ON topic_users.topic_id = mapped_topic.original_id AND mapped_topic.type = ?1
             JOIN mapped.ids mapped_user
               ON topic_users.user_id = mapped_user.original_id AND mapped_user.type = ?2
      ORDER BY topic_users.topic_id, topic_users.user_id
    SQL

    private

    def transform_row(row)
      topic_id = row[:discourse_topic_id]
      user_id = row[:discourse_user_id]

      return nil unless @existing_topic_users.add?(topic_id, user_id)

      row[:notification_level] = ensure_valid_value(
        value: row[:notification_level],
        allowed_set: NOTIFICATION_LEVELS,
        default_value: DEFAULT_NOTIFICATION_LEVEL,
      )
      row[:notifications_reason_id] = ensure_valid_value(
        value: row[:notifications_reason_id],
        allowed_set: NOTIFICATION_REASONS,
        default_value: DEFAULT_NOTIFICATION_REASON,
      )

      row[:total_msecs_viewed] ||= 0

      row[:topic_id] = topic_id
      row[:user_id] = user_id

      super
    end
  end
end
