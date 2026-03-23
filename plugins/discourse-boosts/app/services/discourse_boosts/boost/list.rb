# frozen_string_literal: true

module DiscourseBoosts
  class Boost::List
    include Service::Base

    PAGE_SIZE = 20

    params do
      attribute :username, :string
      attribute :before_boost_id, :integer
      attribute :direction, :string

      validates :username, presence: true
      validates :direction, presence: true, inclusion: { in: %w[given received] }
    end

    model :target_user
    policy :can_see_boosts

    model :boosts, optional: true

    private

    def fetch_target_user(params:, guardian:)
      username_lower = params.username.downcase

      return guardian.user if guardian.user&.username_lower == username_lower

      scope = User.where(username_lower:)
      scope = scope.where(active: true) unless guardian.user&.staff?
      scope.first
    end

    def can_see_boosts(params:, guardian:, target_user:)
      if params.direction == "received"
        guardian.can_see_notifications?(target_user)
      else
        guardian.can_see_profile?(target_user)
      end
    end

    def fetch_boosts(params:, guardian:, target_user:)
      direction =
        if params.direction == "received"
          { posts: { user: target_user } }
        else
          { user: target_user }
        end

      boosts =
        DiscourseBoosts::Boost
          .joins(:post)
          .joins("INNER JOIN topics ON topics.id = posts.topic_id")
          .where(direction)
          .where("posts.deleted_at IS NULL")
          .where("topics.deleted_at IS NULL")
          .merge(Post.secured(guardian))
          .merge(Topic.listable_topics.visible.secured(guardian))
          .includes(:user, post: %i[topic user])

      if guardian.user
        ignored_user_ids = guardian.user.ignored_user_ids
        if ignored_user_ids.present?
          boosts =
            boosts.where(
              "discourse_boosts.user_id NOT IN (?) OR EXISTS (SELECT 1 FROM users WHERE users.id = discourse_boosts.user_id AND (users.admin OR users.moderator))",
              ignored_user_ids,
            )
        end
      end

      boosts =
        boosts.where("discourse_boosts.id < ?", params.before_boost_id) if params.before_boost_id

      boosts.order(id: :desc).limit(PAGE_SIZE)
    end
  end
end
