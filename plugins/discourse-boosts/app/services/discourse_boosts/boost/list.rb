# frozen_string_literal: true

module DiscourseBoosts
  class Boost::List
    include Service::Base

    PAGE_SIZE = 20

    params do
      attribute :username, :string
      attribute :before_boost_id, :integer

      validates :username, presence: true
    end

    model :target_user
    policy :can_see_profile

    model :boosts, optional: true

    private

    def fetch_target_user(params:, guardian:)
      username_lower = params.username.downcase

      return guardian.user if guardian.user&.username_lower == username_lower

      scope = User.where(username_lower:)
      scope = scope.where(active: true) unless guardian.user&.staff?
      scope.first
    end

    def can_see_profile(guardian:, target_user:)
      guardian.can_see_profile?(target_user)
    end

    def fetch_boosts(params:, guardian:, target_user:)
      boosts =
        DiscourseBoosts::Boost
          .joins(:post)
          .joins("INNER JOIN topics ON topics.id = posts.topic_id")
          .where(posts: { user_id: target_user.id })
          .where("posts.deleted_at IS NULL")
          .where("topics.deleted_at IS NULL")
          .includes(:user, post: %i[topic user])

      boosts =
        guardian.filter_allowed_categories(
          boosts.joins("LEFT JOIN categories ON categories.id = topics.category_id"),
        )

      boosts =
        boosts.where("discourse_boosts.id < ?", params.before_boost_id) if params.before_boost_id

      boosts.order(created_at: :desc).limit(PAGE_SIZE)
    end
  end
end
