# frozen_string_literal: true

module Migrations::Importer::Steps
  class UserBadges < ::Migrations::Importer::CopyStep
    # TODO:(selase): Add posts dependency once we have posts
    depends_on :users, :badges

    requires_set :existing_user_badges, "SELECT user_id, badge_id, seq FROM user_badges"

    column_names %i[badge_id created_at granted_at granted_by_id is_favorite post_id seq user_id]

    total_rows_query <<~SQL, MappingType::USERS, MappingType::BADGES
      SELECT COUNT(*)
      FROM user_badges
           JOIN mapped.ids mapped_user
             ON user_badges.user_id = mapped_user.original_id AND mapped_user.type = ?1
           JOIN mapped.ids mapped_badge
             ON user_badges.badge_id = mapped_badge.original_id AND mapped_badge.type = ?2
    SQL

    rows_query <<~SQL, MappingType::USERS, MappingType::BADGES, MappingType::POSTS
      SELECT user_badges.*,
             ROW_NUMBER() OVER (PARTITION BY user_badges.user_id, user_badges.badge_id
                                ORDER BY user_badges.granted_at) - 1 AS seq,
             mapped_user.discourse_id                                AS discourse_user_id,
             mapped_badge.discourse_id                               AS discourse_badge_id,
             mapped_granted_by.discourse_id                          AS discourse_granted_by_id,
             mapped_post.discourse_id                                AS discourse_post_id
      FROM user_badges
           JOIN mapped.ids mapped_user
             ON user_badges.user_id = mapped_user.original_id AND mapped_user.type = ?1
           JOIN mapped.ids mapped_badge
             ON user_badges.badge_id = mapped_badge.original_id AND mapped_badge.type = ?2
           LEFT JOIN mapped.ids mapped_granted_by
             ON user_badges.granted_by_id = mapped_granted_by.original_id AND mapped_granted_by.type = ?1
           LEFT JOIN mapped.ids mapped_post
             ON user_badges.post_id = mapped_post.original_id AND mapped_post.type = ?3
      ORDER BY discourse_user_id,
               discourse_badge_id,
               COALESCE(user_badges.granted_at, user_badges.created_at)
    SQL

    private

    def transform_row(row)
      badge_id = row[:discourse_badge_id]
      user_id = row[:discourse_user_id]

      # TODO:(selase): Is there a scenario where we might offset the seq based off
      #                the existing user badges?
      return nil unless @existing_user_badges.add?(user_id, badge_id, row[:seq])

      row[:is_favorite] ||= false
      row[:badge_id] = badge_id
      row[:user_id] = user_id
      row[:post_id] = row[:discourse_post_id]
      row[:granted_by_id] = row[:discourse_granted_by_id] || Discourse::SYSTEM_USER_ID

      super
    end
  end
end
