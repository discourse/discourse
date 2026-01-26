# frozen_string_literal: true

module Migrations::Converters::Discourse
  class TopicTags < ::Migrations::Converters::Base::ProgressStep
    attr_accessor :source_db

    def max_progress
      @source_db.count <<~SQL
        SELECT COUNT(*)
        FROM topic_tags
      SQL
    end

    def items
      @source_db.query <<~SQL
        SELECT *
        FROM topic_tags
        ORDER BY topic_id, tag_id
      SQL
    end

    def process_item(item)
      IntermediateDB::TopicTag.create(
        topic_id: item[:topic_id],
        tag_id: item[:tag_id],
        created_at: item[:created_at],
      )
    end
  end
end
