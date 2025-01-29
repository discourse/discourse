# frozen_string_literal: true

module Jobs
  class BadgeGrant < ::Jobs::Scheduled
    def self.run
      self.new.execute(nil)
    end

    every 1.day

    def execute(args)
      return unless SiteSetting.enable_badges
      Badge.enabled.pluck(:id).each { |badge_id| Jobs.enqueue(:backfill_badge, badge_id: badge_id) }
    end
  end
end
