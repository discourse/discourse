# frozen_string_literal: true

module Migrations::Converters::Discourse
  class CategoryModerationGroups < ::Migrations::Converters::Base::ProgressStep
    attr_accessor :source_db

    def max_progress
      @source_db.count <<~SQL
        SELECT COUNT(*)
        FROM category_moderation_groups
        WHERE group_id > 0
      SQL
    end

    def items
      @source_db.query <<~SQL
        SELECT *
        FROM category_moderation_groups
        WHERE group_id > 0
      SQL
    end

    def process_item(item)
      IntermediateDB::CategoryModerationGroup.create(
        category_id: item[:category_id],
        group_id: item[:group_id],
      )
    end
  end
end
