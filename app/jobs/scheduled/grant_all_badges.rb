# frozen_string_literal: true

module Jobs
  class GrantAllBadges < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      return unless SiteSetting.enable_badges

      enabled_badges = Badge.enabled

      Discourse.redis.setex("grant_badge_remaining", 2.hours, enabled_badges.count)
      enabled_badges.find_each { |b| Jobs.enqueue(:grant_badge, badge_id: b.id) }
    end
  end
end
