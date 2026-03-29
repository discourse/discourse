# frozen_string_literal: true

require "appreciation_provider"
require "appreciation"

module AppreciationProviders
  class Likes < AppreciationProvider
    def type
      "like"
    end

    def enabled?
      true
    end

    def fetch_given(user:, before:, limit:, guardian:)
      post_actions =
        base_scope(guardian)
          .where(user_id: user.id)
          .where("post_actions.created_at < ?", before)
          .order(created_at: :desc)
          .limit(limit)

      post_actions.map { |pa| to_appreciation(pa, acting_user: pa.user) }
    end

    def fetch_received(user:, before:, limit:, guardian:)
      post_actions =
        base_scope(guardian)
          .where(posts: { user_id: user.id })
          .where("post_actions.created_at < ?", before)
          .order(created_at: :desc)
          .limit(limit)

      post_actions.map { |pa| to_appreciation(pa, acting_user: pa.user) }
    end

    private

    def base_scope(guardian)
      scope =
        PostAction
          .where(post_action_type_id: PostActionType::LIKE_POST_ACTION_ID, deleted_at: nil)
          .joins(post: :topic)
          .where("posts.deleted_at IS NULL")
          .where("topics.deleted_at IS NULL")
          .merge(Post.secured(guardian))
          .merge(Topic.listable_topics.visible.secured(guardian))
          .includes(:user, post: %i[topic user])

      # Exclude likes that are also tracked as reactions to avoid duplicates
      if reactions_table_exists?
        scope = scope.joins(<<~SQL).where("discourse_reactions_reaction_users.id IS NULL")
              LEFT JOIN discourse_reactions_reaction_users
                ON discourse_reactions_reaction_users.post_id = post_actions.post_id
                AND discourse_reactions_reaction_users.user_id = post_actions.user_id
            SQL
      end

      scope
    end

    def reactions_table_exists?
      @reactions_table_exists ||=
        ActiveRecord::Base.connection.table_exists?("discourse_reactions_reaction_users")
    end

    def to_appreciation(post_action, acting_user:)
      Appreciation.new(
        type: "like",
        created_at: post_action.created_at,
        post: post_action.post,
        acting_user: acting_user,
      )
    end
  end
end
