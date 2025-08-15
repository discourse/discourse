# frozen_string_literal: true

module Migrations::Converters::Discourse
  class UserBadges < ::Migrations::Converters::Base::ProgressStep
    attr_accessor :source_db

    def max_progress
      @source_db.count <<~SQL
        SELECT COUNT(*) FROM user_badges
      SQL
    end

    def items
      @source_db.query <<~SQL
        SELECT *
        FROM user_badges
        WHERE user_id >= 0
        ORDER BY user_id, badge_id, granted_at
      SQL
    end

    def process_item(item)
      IntermediateDB::UserBadge.create(
        badge_id: item[:badge_id],
        created_at: item[:created_at],
        granted_at: item[:granted_at],
        granted_by_id: item[:granted_by_id],
        is_favorite: item[:is_favorite],
        post_id: item[:post_id],
        user_id: item[:user_id],
      )
    end
  end
end
