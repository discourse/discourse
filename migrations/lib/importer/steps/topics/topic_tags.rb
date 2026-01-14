# frozen_string_literal: true

module Migrations::Importer::Steps
  class TopicTags < ::Migrations::Importer::CopyStep
    depends_on :topics, :tags

    requires_set :existing_topic_tags, "SELECT topic_id, tag_id FROM topic_tags"

    column_names %i[topic_id tag_id created_at updated_at]

    total_rows_query <<~SQL, MappingType::TOPICS, MappingType::TAGS
      SELECT COUNT(*)
        FROM topic_tags
             JOIN mapped.ids mapped_topic
               ON topic_tags.topic_id = mapped_topic.original_id AND mapped_topic.type = ?1
             JOIN mapped.ids mapped_tag
               ON topic_tags.tag_id = mapped_tag.original_id AND mapped_tag.type = ?2
    SQL

    rows_query <<~SQL, MappingType::TOPICS, MappingType::TAGS
      SELECT topic_tags.*,
             mapped_topic.discourse_id AS discourse_topic_id,
             mapped_tag.discourse_id   AS discourse_tag_id
        FROM topic_tags
             JOIN mapped.ids mapped_topic
               ON topic_tags.topic_id = mapped_topic.original_id AND mapped_topic.type = ?1
             JOIN mapped.ids mapped_tag
               ON topic_tags.tag_id = mapped_tag.original_id AND mapped_tag.type = ?2
      ORDER BY topic_tags.topic_id, topic_tags.tag_id
    SQL

    private

    def transform_row(row)
      topic_id = row[:discourse_topic_id]
      tag_id = row[:discourse_tag_id]

      return nil unless @existing_topic_tags.add?(topic_id, tag_id)

      row[:topic_id] = topic_id
      row[:tag_id] = tag_id

      super
    end
  end
end
