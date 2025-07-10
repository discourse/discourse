# frozen_string_literal: true

module DiscourseReactions::TopicViewSerializerExtension
  include DiscourseReactions::PostsReactionLoader

  def self.load_post_action_reaction_users_for_posts(post_ids)
    PostAction
      .joins(
        "LEFT JOIN discourse_reactions_reaction_users ON discourse_reactions_reaction_users.post_id = post_actions.post_id AND discourse_reactions_reaction_users.user_id = post_actions.user_id",
      )
      .where(post_id: post_ids)
      .where("post_actions.deleted_at IS NULL")
      .where(post_action_type_id: PostActionType::LIKE_POST_ACTION_ID)
      .where(
        "post_actions.post_id IN (#{DiscourseReactions::PostActionExtension.post_action_with_reaction_user_sql})",
        valid_reactions: DiscourseReactions::Reaction.reactions_counting_as_like,
      )
      .reduce({}) do |hash, post_action|
        hash[post_action.post_id] ||= {}
        hash[post_action.post_id][post_action.id] = post_action
        hash
      end
  end

  def posts
    posts_with_reactions
    super
  end

  def self.prepended(base)
    def base.posts_reaction_users_count(post_ids)
      posts_reaction_users_count_query =
        DB.query(
          <<~SQL,
        SELECT union_subquery.post_id, COUNT(DISTINCT(union_subquery.user_id)) FROM (
            SELECT user_id, post_id FROM post_actions
              WHERE post_id IN (:post_ids)
                AND post_action_type_id = :like_id
                AND deleted_at IS NULL
          UNION ALL
            SELECT discourse_reactions_reaction_users.user_id, posts.id from posts
              LEFT JOIN discourse_reactions_reactions ON discourse_reactions_reactions.post_id = posts.id
              LEFT JOIN discourse_reactions_reaction_users ON discourse_reactions_reaction_users.reaction_id = discourse_reactions_reactions.id
              WHERE posts.id IN (:post_ids)
        ) AS union_subquery WHERE union_subquery.post_ID IS NOT NULL GROUP BY union_subquery.post_id
      SQL
          post_ids: Array.wrap(post_ids),
          like_id: PostActionType::LIKE_POST_ACTION_ID,
        )

      posts_reaction_users_count_query.each_with_object({}) do |row, hash|
        hash[row.post_id] = row.count
      end
    end
  end
end
