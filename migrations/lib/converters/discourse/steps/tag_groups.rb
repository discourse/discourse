# frozen_string_literal: true

module Migrations::Converters::Discourse
  class TagGroups < ::Migrations::Converters::Base::ProgressStep
    attr_accessor :source_db

    def max_progress
      @source_db.count <<~SQL
        SELECT COUNT(*) FROM tag_groups
      SQL
    end

    def items
      @source_db.query <<~SQL
        SELECT * FROM tag_groups
      SQL
    end

    def process_item(item)
      IntermediateDB::TagGroup.create(
        original_id: item[:id],
        created_at: item[:created_at],
        name: item[:name],
        one_per_topic: item[:one_per_topic],
        parent_tag_id: item[:parent_tag_id],
      )
    end
  end
end
