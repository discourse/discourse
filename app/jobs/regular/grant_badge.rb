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

      # If this instance is among the last few jobs to be processed, consider
      # rescheduling the EnsureBadgeConsistency job. This ensures the job is
      # scheduled only once after all badges scheduled by GrantAllBadges have
      # been granted.
      if Sidekiq::Queue.new.count { |job| job.klass =~ /GrantBadge/ } == 0
        DistributedMutex.synchronize("ensure_badge_consistency") do
          Jobs.cancel_scheduled_job(:ensure_badge_consistency)
          Jobs.enqueue_in(1.minute, :ensure_badge_consistency)
        end
      end
    end
  end
end
