# frozen_string_literal: true

module DiscourseBoosts
  class Boost::Create
    include Service::Base

    params do
      attribute :post_id, :integer
      attribute :raw, :string

      before_validation { self.raw = raw.to_s.strip }

      validates :post_id, presence: true
      validates :raw, presence: true, length: { maximum: 16 }
    end

    model :post
    policy :can_boost_post
    policy :within_user_boost_limit
    policy :within_post_boost_limit

    transaction { model :boost, :create_boost }

    only_if(:notify_post_author?) { step :create_notification }

    private

    def fetch_post(params:)
      Post.find_by(id: params.post_id)
    end

    def can_boost_post(guardian:, post:)
      guardian.can_see?(post) && post.user_id != guardian.user.id
    end

    def within_user_boost_limit(guardian:, post:)
      existing_count =
        DiscourseBoosts::Boost.where(post_id: post.id, user_id: guardian.user.id).count
      existing_count < SiteSetting.discourse_boosts_max_per_user_per_post
    end

    def within_post_boost_limit(post:)
      DiscourseBoosts::Boost.where(post_id: post.id).count <
        SiteSetting.discourse_boosts_max_per_post
    end

    def create_boost(params:, guardian:, post:)
      DiscourseBoosts::Boost.create(post:, user: guardian.user, raw: params.raw)
    end

    def notify_post_author?(post:)
      post.user.user_option.boost_notifications_level != 2
    end

    def create_notification(boost:)
      Notification.consolidate_or_create!(
        user_id: boost.post.user_id,
        notification_type: Notification.types[:boost],
        topic_id: boost.post.topic_id,
        post_number: boost.post.post_number,
        data: {
          display_username: boost.user.username,
          display_name: boost.user.name,
          boost_raw: boost.raw,
          topic_title: boost.post.topic.title,
        }.to_json,
      )
    end
  end
end
