# frozen_string_literal: true

require "appreciation"
require "appreciation_provider"

module AppreciationProviders
  class Boosts < AppreciationProvider
    def type
      "boost"
    end

    def enabled?
      SiteSetting.discourse_boosts_enabled
    end

    def fetch_given(user:, before:, limit:, guardian:)
      boosts =
        base_scope(guardian)
          .where(discourse_boosts: { user_id: user.id })
          .where("discourse_boosts.created_at < ?", before)
          .order("discourse_boosts.created_at DESC")
          .limit(limit)

      boosts = filter_ignored_users(boosts, guardian)
      boosts.map { |b| to_appreciation(b, acting_user: b.user) }
    end

    def fetch_received(user:, before:, limit:, guardian:)
      boosts =
        base_scope(guardian)
          .where(posts: { user_id: user.id })
          .where("discourse_boosts.created_at < ?", before)
          .order("discourse_boosts.created_at DESC")
          .limit(limit)

      boosts = filter_ignored_users(boosts, guardian)
      boosts.map { |b| to_appreciation(b, acting_user: b.user) }
    end

    private

    def base_scope(guardian)
      DiscourseBoosts::Boost
        .joins(:post)
        .joins("INNER JOIN topics ON topics.id = posts.topic_id")
        .where("posts.deleted_at IS NULL")
        .where("topics.deleted_at IS NULL")
        .merge(Post.secured(guardian))
        .merge(Topic.listable_topics.visible.secured(guardian))
        .includes(:user, post: %i[topic user])
    end

    def filter_ignored_users(boosts, guardian)
      return boosts unless guardian.user

      ignored_user_ids = guardian.user.ignored_user_ids
      return boosts if ignored_user_ids.blank?

      boosts.where(
        "discourse_boosts.user_id NOT IN (?) OR EXISTS (SELECT 1 FROM users WHERE users.id = discourse_boosts.user_id AND (users.admin OR users.moderator))",
        ignored_user_ids,
      )
    end

    def to_appreciation(boost, acting_user:)
      Appreciation.new(
        type: "boost",
        created_at: boost.created_at,
        post: boost.post,
        acting_user: acting_user,
        metadata: {
          raw: boost.raw,
          cooked: boost.cooked,
        },
      )
    end
  end
end
