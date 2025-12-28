# frozen_string_literal: true

module DiscourseReactions::PostsReactionLoader
  def posts_with_reactions
    return unless SiteSetting.discourse_reactions_enabled

    posts = object.posts
    post_ids = posts.map(&:id).uniq

    # Preload reactions (for counter_cache reaction_users_count)
    ActiveRecord::Associations::Preloader.new(records: posts, associations: [:reactions]).call

    # Batch query: get reaction_users_count for all posts
    posts_reaction_users_count = TopicViewSerializer.posts_reaction_users_count(post_ids)

    # Batch query: get current user's reaction_users for all posts (if logged in)
    current_user_reactions = {}
    if scope&.user
      DiscourseReactions::ReactionUser
        .joins(:reaction)
        .where(post_id: post_ids, user_id: scope.user.id)
        .where("discourse_reactions_reactions.reaction_users_count IS NOT NULL")
        .select(
          "discourse_reactions_reaction_users.post_id",
          "discourse_reactions_reaction_users.created_at",
          "discourse_reactions_reactions.reaction_value",
        )
        .each { |ru| current_user_reactions[ru.post_id] = ru }
    end

    # Batch query: get current user's likes for all posts (if logged in)
    current_user_likes = {}
    if scope&.user
      PostAction
        .where(
          post_id: post_ids,
          user_id: scope.user.id,
          post_action_type_id: PostActionType::LIKE_POST_ACTION_ID,
          deleted_at: nil,
        )
        .each { |pa| current_user_likes[pa.post_id] = pa }
    end

    # Batch query: get filtered likes count for all posts
    # This excludes likes from users who have a reaction (to avoid double-counting)
    excluded_reactions = DiscourseReactions::Reaction.reactions_excluded_from_like
    main_reaction = DiscourseReactions::Reaction.main_reaction_id
    excluded_list = excluded_reactions + [main_reaction]

    posts_likes_count =
      DB
        .query(
          <<~SQL,
          SELECT post_actions.post_id, COUNT(*) as likes_count
          FROM post_actions
          WHERE post_actions.post_id IN (:post_ids)
            AND post_actions.post_action_type_id = :like_type
            AND post_actions.deleted_at IS NULL
            AND post_actions.user_id NOT IN (
              SELECT discourse_reactions_reaction_users.user_id
              FROM discourse_reactions_reaction_users
              INNER JOIN discourse_reactions_reactions
                ON discourse_reactions_reactions.id = discourse_reactions_reaction_users.reaction_id
              WHERE discourse_reactions_reactions.post_id = post_actions.post_id
                AND discourse_reactions_reactions.reaction_value NOT IN (:excluded_list)
            )
            AND post_actions.id NOT IN (
              SELECT pa.id
              FROM post_actions pa
              INNER JOIN discourse_reactions_reaction_users
                ON discourse_reactions_reaction_users.post_id = pa.post_id
                AND discourse_reactions_reaction_users.user_id = pa.user_id
              INNER JOIN discourse_reactions_reactions
                ON discourse_reactions_reactions.id = discourse_reactions_reaction_users.reaction_id
              WHERE pa.post_id = post_actions.post_id
                AND pa.post_action_type_id = :like_type
                AND discourse_reactions_reactions.reaction_value = :main_reaction
            )
          GROUP BY post_actions.post_id
        SQL
          post_ids:,
          like_type: PostActionType::LIKE_POST_ACTION_ID,
          excluded_list:,
          main_reaction:,
        )
        .to_h { |row| [row.post_id, row.likes_count] }

    posts.each do |post|
      post.reaction_users_count = posts_reaction_users_count[post.id].to_i
      post.current_user_reaction = current_user_reactions[post.id]
      post.current_user_like = current_user_likes[post.id]
      post.likes_count_for_reactions = posts_likes_count[post.id].to_i
      post.reactions_data_preloaded = true
    end
  end
end
