# frozen_string_literal: true

module Jobs
  class GrantAllBadges < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      return unless SiteSetting.enable_badges

      Badge.enabled.find_each { |b| Jobs.enqueue(:grant_badge, badge_id: b.id) }
    end
  end
end
