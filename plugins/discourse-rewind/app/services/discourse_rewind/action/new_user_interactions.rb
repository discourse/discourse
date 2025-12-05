# frozen_string_literal: true

# Tracks how much this user interacted with new users (created this year)
# Shows veteran mentorship and community building behavior
module DiscourseRewind
  module Action
    class NewUserInteractions < BaseReport
      FakeData = {
        data: {
          total_interactions: 127,
          likes_given: 45,
          replies_to_new_users: 62,
          mentions_to_new_users: 20,
          topics_with_new_users: 8,
          unique_new_users: 24,
          new_users_count: 156,
        },
        identifier: "new-user-interactions",
      }

      def call
        return FakeData if Rails.env.development?
        year_start = Date.new(date.first.year, 1, 1)

        # Find users who created accounts this year
        new_user_ids =
          User
            .real
            .where("created_at >= ? AND created_at <= ?", year_start, date.last)
            .where("id != ?", user.id)
            .pluck(:id)

        return if new_user_ids.empty?

        # Count likes given to new users
        liked_user_ids =
          UserAction
            .where(
              acting_user_id: user.id,
              user_id: new_user_ids,
              action_type: UserAction::WAS_LIKED,
            )
            .where(created_at: date)
            .distinct
            .pluck(:user_id)

        # Count replies to new users' posts
        replied_user_ids =
          Post
            .joins(
              "INNER JOIN posts AS parent_posts ON posts.reply_to_post_number = parent_posts.post_number AND posts.topic_id = parent_posts.topic_id",
            )
            .where(posts: { user_id: user.id, deleted_at: nil, created_at: date })
            .where("parent_posts.user_id": new_user_ids)
            .distinct
            .pluck("parent_posts.user_id")

        # Count direct mentions to new users
        mentioned_user_ids =
          Post
            .joins(
              "INNER JOIN user_actions ON user_actions.target_post_id = posts.id AND user_actions.action_type = #{UserAction::MENTION}",
            )
            .where(posts: { user_id: user.id, deleted_at: nil, created_at: date })
            .where(user_actions: { user_id: new_user_ids })
            .distinct
            .pluck("user_actions.user_id")

        # Unique new users interacted with
        unique_new_users = (liked_user_ids + replied_user_ids + mentioned_user_ids).uniq.count

        return if unique_new_users == 0

        { data: { unique_new_users: unique_new_users }, identifier: "new-user-interactions" }
      end
    end
  end
end
