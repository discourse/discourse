# frozen_string_literal: true

module DiscourseReactions::ReactionsSerializerHelpers
  def self.preload_post_reactions(posts, user)
    posts = Array(posts).compact
    return { reactions: {}, reaction_users_count: {} } if posts.blank?

    ActiveRecord::Associations::Preloader.new(
      records: posts,
      associations: [:post_actions, { reactions: { reaction_users: :user } }],
    ).call

    post_ids = posts.map(&:id).uniq
    ignored_user_ids = user&.ignored_user_ids || []
    ignored_user_ids_set = ignored_user_ids.to_set

    reaction_users_count_map =
      TopicViewSerializer.posts_reaction_users_count(post_ids, ignored_user_ids: ignored_user_ids)
    post_actions_with_reaction_users =
      DiscourseReactions::TopicViewSerializerExtension.load_post_action_reaction_users_for_posts(
        post_ids,
      )

    main_reaction = DiscourseReactions::Reaction.main_reaction_id
    excluded = DiscourseReactions::Reaction.reactions_excluded_from_like

    excluded_filter = excluded.present? ? "AND dr.reaction_value NOT IN (:excluded)" : ""
    ignored_users_filter =
      ignored_user_ids.present? ? "AND pa.user_id NOT IN (:ignored_user_ids)" : ""

    sql_params = {
      post_ids: post_ids,
      like_type: PostActionType::LIKE_POST_ACTION_ID,
      main_reaction: main_reaction,
    }
    sql_params[:excluded] = excluded if excluded.present?
    sql_params[:ignored_user_ids] = ignored_user_ids if ignored_user_ids.present?

    likes_rows = DB.query(<<~SQL, **sql_params)
      SELECT pa.post_id, COUNT(*) as likes_count
      FROM post_actions pa
      WHERE pa.deleted_at IS NULL
        AND pa.post_id IN (:post_ids)
        AND pa.post_action_type_id = :like_type
        #{ignored_users_filter}
        AND NOT EXISTS (
          SELECT 1 FROM discourse_reactions_reaction_users dru
          JOIN discourse_reactions_reactions dr ON dr.id = dru.reaction_id
          WHERE dr.post_id = pa.post_id
            AND dru.user_id = pa.user_id
            AND dr.reaction_value != :main_reaction
            #{excluded_filter}
        )
        AND NOT EXISTS (
          SELECT 1 FROM discourse_reactions_reaction_users dru
          JOIN discourse_reactions_reactions dr ON dr.id = dru.reaction_id
          WHERE dr.post_id = pa.post_id
            AND dru.user_id = pa.user_id
            AND dr.reaction_value = :main_reaction
        )
      GROUP BY pa.post_id
    SQL

    likes_map = likes_rows.each_with_object({}) { |row, hash| hash[row.post_id] = row.likes_count }
    precomputed_reactions_map = {}

    posts.each do |post|
      post.reaction_users_count = reaction_users_count_map[post.id].to_i
      post.post_actions_with_reaction_users = post_actions_with_reaction_users[post.id] || {}

      reactions =
        post
          .emoji_reactions
          .select { |reaction| reaction.reaction_users_count.to_i > 0 }
          .filter_map do |reaction|
            count =
              if ignored_user_ids_set.present?
                reaction.reaction_users.count { |ru| !ignored_user_ids_set.include?(ru.user_id) }
              else
                reaction.reaction_users_count
              end

            next if count.to_i.zero?

            { id: reaction.reaction_value, type: reaction.reaction_type.to_sym, count: count }
          end

      likes = likes_map[post.id] || 0

      if likes > 0
        reaction_likes, reactions =
          reactions.partition { |reaction| reaction[:id] == main_reaction }
        reactions << {
          id: main_reaction,
          type: :emoji,
          count: likes + reaction_likes.sum { |reaction| reaction[:count] },
        }
      end

      precomputed_reactions_map[post.id] = reactions.sort_by do |reaction|
        [-reaction[:count].to_i, reaction[:id]]
      end
      post.precomputed_reactions = precomputed_reactions_map[post.id]
    end

    { reactions: precomputed_reactions_map, reaction_users_count: reaction_users_count_map }
  end

  def self.reactions_for_post(post, scope = nil)
    return post.precomputed_reactions unless post.precomputed_reactions.nil?

    ignored_ids = scope&.user&.ignored_user_ids || []
    reactions = []
    reaction_users_counting_as_like = Set.new

    post
      .emoji_reactions
      .select { |reaction| reaction[:reaction_users_count] }
      .each do |reaction|
        count =
          if ignored_ids.any?
            reaction.reaction_users.count { |ru| !ignored_ids.include?(ru.user_id) }
          else
            reaction.reaction_users_count
          end
        next if count.to_i.zero?
        reactions << {
          id: reaction.reaction_value,
          type: reaction.reaction_type.to_sym,
          count: count,
        }

        # NOTE: It does not matter if the reaction is currently an enabled one,
        # we need to handle historical data here too so we don't see double-ups in the UI.
        if !DiscourseReactions::Reaction.reactions_excluded_from_like.include?(
             reaction.reaction_value,
           ) && reaction.reaction_value != DiscourseReactions::Reaction.main_reaction_id
          reaction_users_counting_as_like.merge(reaction.reaction_users.pluck(:user_id))
        end
      end

    likes_query = post.post_actions.where(post_action_type_id: PostActionType::LIKE_POST_ACTION_ID)

    likes_query = likes_query.where.not(user_id: ignored_ids) if ignored_ids.any?

    # Get rid of any PostAction records that match up to a ReactionUser
    # that is NOT main_reaction_id and is NOT excluded, otherwise we double
    # up on the count/reaction shown in the UI.
    if reaction_users_counting_as_like.any?
      likes_query = likes_query.where.not(user_id: reaction_users_counting_as_like.to_a)
    end

    # Also get rid of any PostAction records that match up to a ReactionUser
    # that is now the main_reaction_id and has historical data.
    # This subquery checks if there's a matching ReactionUser with main_reaction_id.
    likes_query =
      likes_query.where(
        <<~SQL,
          post_actions.id NOT IN (
            SELECT post_actions.id
            FROM post_actions
            INNER JOIN discourse_reactions_reaction_users
              ON discourse_reactions_reaction_users.post_id = post_actions.post_id
              AND discourse_reactions_reaction_users.user_id = post_actions.user_id
            INNER JOIN discourse_reactions_reactions
              ON discourse_reactions_reactions.id = discourse_reactions_reaction_users.reaction_id
            WHERE post_actions.post_id = :post_id
              AND post_actions.post_action_type_id = :like_type
              AND discourse_reactions_reactions.reaction_value = :main_reaction
          )
        SQL
        post_id: post.id,
        like_type: PostActionType::LIKE_POST_ACTION_ID,
        main_reaction: DiscourseReactions::Reaction.main_reaction_id,
      )

    likes = likes_query.count

    return reactions.sort_by { |reaction| [-reaction[:count].to_i, reaction[:id]] } if likes.zero?

    # Reactions using main_reaction_id normally only have a `PostAction` record.
    # If main_reaction_id was changed, historical `ReactionUser` rows can also
    # exist, so fold them into the like count instead of rendering them separately.
    reaction_likes, reactions =
      reactions.partition { |r| r[:id] == DiscourseReactions::Reaction.main_reaction_id }

    reactions << {
      id: DiscourseReactions::Reaction.main_reaction_id,
      type: :emoji,
      count: likes + reaction_likes.sum { |r| r[:count] },
    }

    reactions.sort_by { |reaction| [-reaction[:count].to_i, reaction[:id]] }
  end

  def self.current_user_reaction_for_post(post, scope)
    return nil if scope.is_anonymous?

    post.emoji_reactions.each do |reaction|
      reaction_user = reaction.reaction_users.find { |ru| ru.user_id == scope.user.id }
      next if reaction_user.blank?

      if reaction.reaction_users_count
        return(
          {
            id: reaction.reaction_value,
            type: reaction.reaction_type.to_sym,
            can_undo: reaction_user.can_undo?,
          }
        )
      end
    end

    like =
      post.post_actions.find do |post_action|
        post_action.post_action_type_id == PostActionType::LIKE_POST_ACTION_ID &&
          !post_action.trashed? && post_action.user_id == scope.user.id
      end

    return nil if like.blank?

    {
      id: DiscourseReactions::Reaction.main_reaction_id,
      type: :emoji,
      can_undo: scope.can_delete_post_action?(like),
    }
  end

  def self.reaction_users_count_for_post(post, scope = nil)
    return post.reaction_users_count unless post.reaction_users_count.nil?

    ignored_ids = scope&.user&.ignored_user_ids || []

    return TopicViewSerializer.posts_reaction_users_count(post.id)[post.id] if ignored_ids.empty?

    DB.query_single(
      <<~SQL,
        SELECT COUNT(DISTINCT user_id) FROM (
          SELECT user_id FROM post_actions
            WHERE post_id = :post_id AND post_action_type_id = :like_id
              AND deleted_at IS NULL AND user_id NOT IN (:ignored_ids)
          UNION
          SELECT drru.user_id FROM discourse_reactions_reaction_users drru
            INNER JOIN discourse_reactions_reactions dr ON dr.id = drru.reaction_id
            WHERE dr.post_id = :post_id AND drru.user_id NOT IN (:ignored_ids)
        ) sub
      SQL
      post_id: post.id,
      ignored_ids: ignored_ids,
      like_id: PostActionType::LIKE_POST_ACTION_ID,
    ).first
  end

  def self.like_action_for_post(post, scope)
    return nil if scope.user.blank?

    if !post.precomputed_reactions.nil? && post.association(:post_actions).loaded?
      post.post_actions.find do |post_action|
        post_action.post_action_type_id == PostActionType.types[:like] &&
          post_action.user_id == scope.user.id && !post_action.trashed?
      end
    else
      PostAction.find_by(
        user_id: scope.user.id,
        post_id: post.id,
        post_action_type_id: PostActionType.types[:like],
      )
    end
  end

  def self.current_user_used_main_reaction_for_post(post, scope)
    return false if scope.is_anonymous?

    like_post_action =
      post.post_actions.find do |post_action|
        post_action.post_action_type_id == PostActionType::LIKE_POST_ACTION_ID &&
          post_action.user_id == scope.user.id && !post_action.trashed?
      end

    has_matching_reaction_user =
      post.emoji_reactions.any? do |reaction|
        reaction.reaction_users.any? { |ru| ru.user_id == scope.user.id } &&
          (
            if SiteSetting.discourse_reactions_allow_any_emoji
              reaction.reaction_value != DiscourseReactions::Reaction.main_reaction_id
            else
              DiscourseReactions::Reaction.reactions_counting_as_like.include?(
                reaction.reaction_value,
              )
            end
          )
      end

    like_post_action.present? && !has_matching_reaction_user
  end

  def self.op_reactions_data_for_topic(topic, scope)
    return nil unless topic.first_post

    post = topic.first_post
    like_action = like_action_for_post(post, scope)

    {
      id: post.id,
      user_id: post.user_id,
      yours: post.user_id == scope.current_user&.id,
      reactions: reactions_for_post(post, scope),
      current_user_reaction: current_user_reaction_for_post(post, scope),
      current_user_used_main_reaction: current_user_used_main_reaction_for_post(post, scope),
      reaction_users_count: reaction_users_count_for_post(post, scope) || 0,
      likeAction: {
        canToggle: like_action ? scope.can_delete_post_action?(like_action) : true,
      },
    }
  end
end
