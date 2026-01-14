# frozen_string_literal: true

module Migrations::Importer::Steps
  class TopicAllowedGroups < ::Migrations::Importer::CopyStep
    depends_on :topics, :groups

    requires_set :existing_topic_allowed_groups,
                 "SELECT topic_id, group_id FROM topic_allowed_groups"

    column_names %i[topic_id group_id]

    total_rows_query <<~SQL, MappingType::TOPICS, MappingType::GROUPS, Archetype.private_message
      SELECT COUNT(*)
        FROM topic_allowed_groups
             JOIN mapped.ids mapped_topic
               ON topic_allowed_groups.topic_id = mapped_topic.original_id AND mapped_topic.type = ?1
             JOIN mapped.ids mapped_group
               ON topic_allowed_groups.group_id = mapped_group.original_id AND mapped_group.type = ?2
             JOIN topics
               ON topic_allowed_groups.topic_id = topics.original_id AND topics.archetype = ?3
    SQL

    rows_query <<~SQL, MappingType::TOPICS, MappingType::GROUPS, Archetype.private_message
      SELECT topic_allowed_groups.*,
             mapped_topic.discourse_id AS discourse_topic_id,
             mapped_group.discourse_id AS discourse_group_id
        FROM topic_allowed_groups
             JOIN mapped.ids mapped_topic
               ON topic_allowed_groups.topic_id = mapped_topic.original_id AND mapped_topic.type = ?1
             JOIN mapped.ids mapped_group
               ON topic_allowed_groups.group_id = mapped_group.original_id AND mapped_group.type = ?2
             JOIN topics
               ON topic_allowed_groups.topic_id = topics.original_id AND topics.archetype = ?3
      ORDER BY topic_allowed_groups.topic_id, topic_allowed_groups.group_id
    SQL

    private

    def transform_row(row)
      topic_id = row[:discourse_topic_id]
      group_id = row[:discourse_group_id]

      return nil unless @existing_topic_allowed_groups.add?(topic_id, group_id)

      row[:topic_id] = topic_id
      row[:group_id] = group_id

      super
    end
  end
end
