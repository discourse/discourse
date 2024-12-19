# frozen_string_literal: true

module Jobs
  class GrantBadge < ::Jobs::Base
    def execute(args)
      return unless SiteSetting.enable_badges

      badge = Badge.enabled.find_by(id: args[:badge_id])
      return unless badge

      # Cancels the scheduled job to ensure badge consistency as the badges are
      # mutating during `BadgeGranter.backfill`.
      Jobs.cancel_scheduled_job(:ensure_badge_consistency)

      begin
        BadgeGranter.backfill(badge)
      rescue => ex
        # TODO - expose errors in UI
        Discourse.handle_job_exception(
          ex,
          error_context({}, code_desc: "Exception granting badges", extra: { badge_id: badge.id }),
        )
      end

      # Re-schedule the job in the future to allow all GrantBadge jobs to start
      # and thus ensuring this job runs only once after all badges scheduled by
      # GrantAllBadges have been granted.
      DistributedMutex.synchronize("ensure_badge_consistency") do
        Jobs.cancel_scheduled_job(:ensure_badge_consistency)
        Jobs.enqueue_in(5.minutes, :ensure_badge_consistency)
      end
    end
  end
end
