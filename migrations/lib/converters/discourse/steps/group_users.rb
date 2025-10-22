# frozen_string_literal: true

module Migrations::Converters::Discourse
  class GroupUsers < ::Migrations::Converters::Base::ProgressStep
    attr_accessor :source_db

    def max_progress
      @source_db.count <<~SQL
        SELECT COUNT(*)
        FROM group_users
        WHERE group_id NOT IN (10, 11, 12, 13, 14) -- Exclude Trust Level groups
              AND user_id > 0
      SQL
    end

    def items
      @source_db.query <<~SQL
        SELECT *
        FROM group_users
        WHERE group_id NOT IN (10, 11, 12, 13, 14) -- Exclude Trust Level groups
              AND user_id > 0
        ORDER BY group_id, user_id
      SQL
    end

    def process_item(item)
      IntermediateDB::GroupUser.create(
        created_at: item[:created_at],
        group_id: item[:group_id],
        user_id: item[:user_id],
        owner: item[:owner],
        notification_level: item[:notification_level],
      )
    end
  end
end
