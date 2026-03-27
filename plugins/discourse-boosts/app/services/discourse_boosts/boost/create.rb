# frozen_string_literal: true

module DiscourseBoosts
  class Boost::Create
    include Service::Base

    params do
      attribute :post_id, :integer
      attribute :raw, :string

      before_validation { self.raw = raw.to_s.strip }

      validates :post_id, presence: true
      validates :raw, presence: true
    end

    model :post
    policy :can_boost_post
    policy :user_has_not_boosted_post
    policy :within_post_boost_limit
    policy :not_blocked_by_watched_words
    model :processed_raw
    model :boost, :create_boost

    step :publish_change
    only_if(:notify_post_author?) { step :create_notification }

    private

    def fetch_post(params:)
      Post.find_by(id: params.post_id)
    end

    def can_boost_post(guardian:, post:)
      guardian.can_see?(post) && post.deleted_at.nil? && post.user_id != guardian.user.id &&
        !guardian.user.silenced?
    end

    def user_has_not_boosted_post(guardian:, post:)
      !DiscourseBoosts::Boost.exists?(post_id: post.id, user_id: guardian.user.id)
    end

    def within_post_boost_limit(post:)
      DiscourseBoosts::Boost.where(post_id: post.id).count <
        SiteSetting.discourse_boosts_max_per_post
    end

    def not_blocked_by_watched_words(params:)
      !WordWatcher.new(params.raw).should_block?
    end

    def fetch_processed_raw(params:)
      WordWatcher.apply_to_text(params.raw)
    end

    def create_boost(processed_raw:, guardian:, post:)
      DiscourseBoosts::Boost.create(post:, user: guardian.user, raw: processed_raw)
    end

    def publish_change(post:, boost:)
      DiscourseBoosts::Boost.publish_add(post, boost)
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
