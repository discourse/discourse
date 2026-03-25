# frozen_string_literal: true

module NestedReplies
  # Batch-compute the full reactions result for all posts in one SQL query.
  # Replicates ReactionsSerializerHelpers.reactions_for_post logic without
  # the per-post COUNT that causes N+1.
  def self.batch_precompute_reactions(posts, post_ids)
    main_reaction = DiscourseReactions::Reaction.main_reaction_id
    excluded = DiscourseReactions::Reaction.reactions_excluded_from_like

    excluded_filter =
      if excluded.present?
        "AND dr.reaction_value NOT IN (:excluded)"
      else
        ""
      end

    sql_params = {
      post_ids: post_ids,
      like_type: PostActionType::LIKE_POST_ACTION_ID,
      main_reaction: main_reaction,
    }
    sql_params[:excluded] = excluded if excluded.present?

    rows = DB.query(<<~SQL, **sql_params)
        SELECT pa.post_id, COUNT(*) as likes_count
        FROM post_actions pa
        WHERE pa.deleted_at IS NULL
          AND pa.post_id IN (:post_ids)
          AND pa.post_action_type_id = :like_type
          AND NOT EXISTS (
            SELECT 1 FROM discourse_reactions_reaction_users dru
            JOIN discourse_reactions_reactions dr ON dr.id = dru.reaction_id
            WHERE dru.post_id = pa.post_id
              AND dru.user_id = pa.user_id
              AND dr.reaction_value != :main_reaction
              #{excluded_filter}
          )
          AND NOT EXISTS (
            SELECT 1 FROM discourse_reactions_reaction_users dru
            JOIN discourse_reactions_reactions dr ON dr.id = dru.reaction_id
            WHERE dru.post_id = pa.post_id
              AND dru.user_id = pa.user_id
              AND dr.reaction_value = :main_reaction
          )
        GROUP BY pa.post_id
      SQL

    likes_map = rows.each_with_object({}) { |row, h| h[row.post_id] = row.likes_count }

    posts.each do |post|
      emoji_reactions = post.emoji_reactions.select { |r| r.reaction_users_count.to_i > 0 }

      reactions =
        emoji_reactions.map do |reaction|
          {
            id: reaction.reaction_value,
            type: reaction.reaction_type.to_sym,
            count: reaction.reaction_users_count,
          }
        end

      likes = likes_map[post.id] || 0

      if likes > 0
        reaction_likes, reactions = reactions.partition { |r| r[:id] == main_reaction }
        reactions << {
          id: main_reaction,
          type: :emoji,
          count: likes + reaction_likes.sum { |r| r[:count] },
        }
      end

      post.precomputed_reactions = reactions.sort_by { |r| [-r[:count].to_i, r[:id]] }
    end
  end
end

require_relative "nested_replies/ancestor_walker"
require_relative "nested_replies/sort"
require_relative "nested_replies/tree_loader"
require_relative "nested_replies/post_preloader"
require_relative "nested_replies/post_tree_serializer"
require_relative "nested_replies/post_serializer_reactions_patch"
require_relative "nested_replies/topic_view_preload"
