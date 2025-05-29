# frozen_string_literal: true

module Migrations::Converters::Discourse
  class Tags < ::Migrations::Converters::Base::ProgressStep
    attr_accessor :source_db

    def max_progress
      @source_db.count <<~SQL
        SELECT COUNT(*) FROM tags
      SQL
    end

    def items
      @source_db.query <<~SQL
        SELECT * FROM tags
      SQL
    end

    def process_item(item)
      IntermediateDB::Tag.create(
        original_id: item[:id],
        created_at: item[:created_at],
        description: item[:description],
        name: item[:name],
        tag_group_id: item[:tag_group_id],
        target_tag_id: item[:target_tag_id],
      )
    end
  end
end
