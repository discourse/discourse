# frozen_string_literal: true

module Migrations::Converters::Discourse
  class TopicAllowedUsers < ::Migrations::Converters::Base::ProgressStep
    attr_accessor :source_db

    def max_progress
      @source_db.count <<~SQL
        SELECT COUNT(*)
        FROM topic_allowed_users
        WHERE user_id > 0
      SQL
    end

    def items
      @source_db.query <<~SQL
        SELECT *
        FROM topic_allowed_users
        WHERE user_id > 0
        ORDER BY topic_id, user_id
      SQL
    end

    def process_item(item)
      IntermediateDB::TopicAllowedUser.create(
        topic_id: item[:topic_id],
        user_id: item[:user_id],
        created_at: item[:created_at],
      )
    end
  end
end
