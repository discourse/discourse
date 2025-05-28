# frozen_string_literal: true

module Migrations::Converters::Discourse
  class TagUsers < ::Migrations::Converters::Base::ProgressStep
    attr_accessor :source_db

    def max_progress
      @source_db.count <<~SQL
        SELECT COUNT(*) FROM tag_users
      SQL
    end

    def items
      @source_db.query <<~SQL
        SELECT * FROM tag_users
      SQL
    end

    def process_item(item)
      IntermediateDB::TagUser.create(
        tag_id: item[:tag_id],
        user_id: item[:user_id],
        created_at: item[:created_at],
        notification_level: item[:notification_level],
        original_id: item[:id],
      )
    end
  end
end
