# frozen_string_literal: true

module DiscourseReactions
  class PostReactionsQuery
    def self.call(post:, reaction_filter: nil, limit: 30, offset: 0)
      query = new(post: post, reaction_filter: reaction_filter, limit: limit, offset: offset)
      [query.rows, query.total]
    end

    def initialize(post:, reaction_filter: nil, limit: 30, offset: 0)
      @post = post
      @reaction_filter = reaction_filter
      @limit = limit
      @offset = offset
    end

    def rows
      @rows ||=
        if specific_reaction?
          DB.query(<<~SQL, **bindings, reaction_filter: reaction_filter)
            #{reactions_select_sql}
            AND dr.reaction_value = :reaction_filter
            ORDER BY drru.created_at ASC
            LIMIT :limit OFFSET :offset
          SQL
        elsif main_reaction_filter?
          DB.query(<<~SQL, **bindings)
            #{plain_likes_select_sql}
            ORDER BY post_actions.created_at ASC
            LIMIT :limit OFFSET :offset
          SQL
        else
          DB.query(<<~SQL, **bindings)
            SELECT * FROM (
              #{reactions_select_sql}
              UNION ALL
              #{plain_likes_select_sql}
            ) combined
            ORDER BY created_at ASC
            LIMIT :limit OFFSET :offset
          SQL
        end
    end

    def total
      @total ||=
        if specific_reaction?
          ReactionUser
            .joins(:reaction)
            .where(
              post_id: post.id,
              discourse_reactions_reactions: {
                reaction_value: reaction_filter,
              },
            )
            .count
        elsif main_reaction_filter?
          plain_likes_scope.count
        else
          ReactionUser.where(post_id: post.id).count + plain_likes_scope.count
        end
    end

    private

    attr_reader :post, :reaction_filter, :limit, :offset

    def main_reaction
      @main_reaction ||= Reaction.main_reaction_id
    end

    def like_type
      PostActionType::LIKE_POST_ACTION_ID
    end

    def shadow_like_filter
      PostActionExtension.strict_filter_reaction_likes_sql
    end

    def specific_reaction?
      reaction_filter.present? && reaction_filter != main_reaction
    end

    def main_reaction_filter?
      reaction_filter == main_reaction
    end

    def bindings
      {
        post_id: post.id,
        like: like_type,
        main_reaction: main_reaction,
        limit: limit,
        offset: offset,
      }
    end

    def plain_likes_scope
      PostAction.where(post_id: post.id).where(shadow_like_filter, like: like_type)
    end

    def reactions_select_sql
      <<~SQL
        SELECT u.id, u.username, u.name, u.uploaded_avatar_id,
               dr.reaction_value AS reaction, drru.created_at
        FROM discourse_reactions_reaction_users drru
        INNER JOIN discourse_reactions_reactions dr ON dr.id = drru.reaction_id
        INNER JOIN users u ON u.id = drru.user_id
        WHERE drru.post_id = :post_id
      SQL
    end

    def plain_likes_select_sql
      <<~SQL
        SELECT u.id, u.username, u.name, u.uploaded_avatar_id,
               :main_reaction AS reaction, post_actions.created_at
        FROM post_actions
        INNER JOIN users u ON u.id = post_actions.user_id
        WHERE post_actions.post_id = :post_id
          AND (#{shadow_like_filter})
      SQL
    end
  end
end
