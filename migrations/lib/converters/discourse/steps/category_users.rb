# frozen_string_literal: true

module Migrations::Converters::Discourse
  class CategoryUsers < ::Migrations::Converters::Base::ProgressStep
    attr_accessor :source_db

    def max_progress
      @source_db.count <<~SQL
        SELECT COUNT(*)
        FROM category_users
        WHERE user_id >= 0
      SQL
    end

    def items
      @source_db.query <<~SQL
        SELECT *
        FROM category_users
        WHERE user_id >= 0
      SQL
    end

    def process_item(item)
      IntermediateDB::CategoryUser.create(
        category_id: item[:category_id],
        last_seen_at: item[:last_seen_at],
        notification_level: item[:notification_level],
        user_id: item[:user_id],
      )
    end
  end
end
