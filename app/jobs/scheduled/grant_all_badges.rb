# frozen_string_literal: true

module Jobs
  class GrantAllBadges < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      return unless SiteSetting.enable_badges

      job_ids = Badge.enabled.map { |b| Jobs.enqueue(:grant_badge, badge_id: b.id) }
      Jobs.enqueue_after(job_ids, :ensure_badge_consistency)
    end
  end
end
