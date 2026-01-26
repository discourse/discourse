# frozen_string_literal: true

module Migrations::Converters::Discourse
  class TopicAllowedGroups < ::Migrations::Converters::Base::ProgressStep
    attr_accessor :source_db

    def max_progress
      @source_db.count <<~SQL
        SELECT COUNT(*) FROM topic_allowed_groups
      SQL
    end

    def items
      @source_db.query <<~SQL
        SELECT *
        FROM topic_allowed_groups
        ORDER BY topic_id, group_id
      SQL
    end

    def process_item(item)
      IntermediateDB::TopicAllowedGroup.create(topic_id: item[:topic_id], group_id: item[:group_id])
    end
  end
end
