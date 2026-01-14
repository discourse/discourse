# frozen_string_literal: true

module Migrations::Importer::Steps
  class TopicAllowedUsers < ::Migrations::Importer::CopyStep
    depends_on :topics, :users

    requires_set :existing_topic_allowed_users,
                 "SELECT topic_id, user_id FROM topic_allowed_users WHERE user_id > 0"

    column_names %i[topic_id user_id created_at updated_at]

    total_rows_query <<~SQL, MappingType::TOPICS, MappingType::USERS, Archetype.private_message
      SELECT COUNT(*)
        FROM topic_allowed_users
             JOIN mapped.ids mapped_topic
               ON topic_allowed_users.topic_id = mapped_topic.original_id AND mapped_topic.type = ?1
             JOIN mapped.ids mapped_user
               ON topic_allowed_users.user_id = mapped_user.original_id AND mapped_user.type = ?2
             JOIN topics
               ON topic_allowed_users.topic_id = topics.original_id AND topics.archetype = ?3
    SQL

    rows_query <<~SQL, MappingType::TOPICS, MappingType::USERS, Archetype.private_message
      SELECT topic_allowed_users.*,
             mapped_topic.discourse_id AS discourse_topic_id,
             mapped_user.discourse_id  AS discourse_user_id
        FROM topic_allowed_users
             JOIN mapped.ids mapped_topic
               ON topic_allowed_users.topic_id = mapped_topic.original_id AND mapped_topic.type = ?1
             JOIN mapped.ids mapped_user
               ON topic_allowed_users.user_id = mapped_user.original_id AND mapped_user.type = ?2
             JOIN topics
               ON topic_allowed_users.topic_id = topics.original_id AND topics.archetype = ?3
      ORDER BY topic_allowed_users.topic_id, topic_allowed_users.user_id
    SQL

    private

    def transform_row(row)
      topic_id = row[:discourse_topic_id]
      user_id = row[:discourse_user_id]

      return nil unless @existing_topic_allowed_users.add?(topic_id, user_id)

      row[:topic_id] = topic_id
      row[:user_id] = user_id

      super
    end
  end
end
