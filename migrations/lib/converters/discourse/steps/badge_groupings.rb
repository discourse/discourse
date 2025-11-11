# frozen_string_literal: true

module Migrations::Converters::Discourse
  class BadgeGroupings < ::Migrations::Converters::Base::ProgressStep
    attr_accessor :source_db

    def max_progress
      @source_db.count <<~SQL
        SELECT COUNT(*)
        FROM badge_groupings
        WHERE id NOT IN (1, 2, 3, 4, 5) -- Exclude system groupings
      SQL
    end

    def items
      @source_db.query <<~SQL
        SELECT *
        FROM badge_groupings
        WHERE id NOT IN (1, 2, 3, 4, 5) -- Exclude system groupings
        ORDER BY id
      SQL
    end

    def process_item(item)
      IntermediateDB::BadgeGrouping.create(
        original_id: item[:id],
        name: item[:name],
        description: item[:description],
        created_at: item[:created_at],
        position: item[:position],
      )
    end
  end
end
