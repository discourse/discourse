# frozen_string_literal: true

module Jobs
  module DiscourseTopicVoting
    class BackfillBadges < ::Jobs::Base
      def execute(args)
        return unless SiteSetting.enable_badges

        first_post_id = Post.where(topic_id: args[:topic_id], post_number: 1).pick(:id)
        return if first_post_id.blank?

        Badge
          .enabled
          .where(name: ::DiscourseTopicVoting::BADGE_NAMES)
          .find_each { |badge| BadgeGranter.backfill(badge, post_ids: [first_post_id]) }
      end
    end
  end
end
