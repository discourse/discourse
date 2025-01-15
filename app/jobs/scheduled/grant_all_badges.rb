# frozen_string_literal: true

module Jobs
  class GrantAllBadges < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      return unless SiteSetting.enable_badges

      Jobs.enqueue_after(:ensure_badge_consistency) do
        Badge.enabled.each { |b| Jobs.enqueue(:grant_badge, badge_id: b.id) }
      end
    end
  end
end
