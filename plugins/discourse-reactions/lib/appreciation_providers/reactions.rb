# frozen_string_literal: true

require "appreciation"
require "appreciation_provider"

module AppreciationProviders
  class Reactions < AppreciationProvider
    def type
      "reaction"
    end

    def enabled?
      SiteSetting.discourse_reactions_enabled
    end

    def fetch_given(user:, before:, limit:, guardian:)
      reaction_users =
        base_scope
          .where(discourse_reactions_reaction_users: { user_id: user.id })
          .where("discourse_reactions_reaction_users.created_at < ?", before)
          .order("discourse_reactions_reaction_users.created_at DESC")
          .limit(limit)

      reaction_users.map { |ru| to_appreciation(ru, acting_user: ru.user) }
    end

    def fetch_received(user:, before:, limit:, guardian:)
      post_ids =
        Post
          .joins(:topic)
          .where(user_id: user.id)
          .merge(guardian.filter_allowed_categories(Post.all))
          .select(:id)

      reaction_users =
        DiscourseReactions::ReactionUser
          .joins(:reaction)
          .where(post_id: post_ids)
          .where.not(discourse_reactions_reactions: { reaction_users_count: nil })
          .where("discourse_reactions_reaction_users.created_at < ?", before)
          .includes(:user, :reaction, post: %i[topic user])
          .order("discourse_reactions_reaction_users.created_at DESC")
          .limit(limit)

      reaction_users.map { |ru| to_appreciation(ru, acting_user: ru.user) }
    end

    private

    def base_scope
      DiscourseReactions::ReactionUser
        .joins(:reaction)
        .joins(
          "INNER JOIN posts ON posts.id = discourse_reactions_reaction_users.post_id AND posts.deleted_at IS NULL",
        )
        .joins("INNER JOIN topics ON topics.id = posts.topic_id AND topics.deleted_at IS NULL")
        .where.not(discourse_reactions_reactions: { reaction_users_count: nil })
        .includes(:user, :reaction, post: %i[topic user])
    end

    def to_appreciation(reaction_user, acting_user:)
      Appreciation.new(
        type: "reaction",
        created_at: reaction_user.created_at,
        post: reaction_user.post,
        acting_user: acting_user,
        metadata: {
          reaction_value: reaction_user.reaction&.reaction_value,
          reaction_type: reaction_user.reaction&.reaction_type,
        },
      )
    end
  end
end
