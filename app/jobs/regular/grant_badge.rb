# frozen_string_literal: true

module Jobs
  class GrantBadge < ::Jobs::Base
    def execute(args)
      return unless SiteSetting.enable_badges

      badge = Badge.enabled.find_by(id: args[:badge_id])
      return unless badge

      begin
        BadgeGranter.backfill(badge)
      rescue => ex
        # TODO - expose errors in UI
        Discourse.handle_job_exception(
          ex,
          error_context({}, code_desc: "Exception granting badges", extra: { badge_id: badge.id }),
        )
      end

      # If this instance is the last job to be processed, schedule the
      # EnsureBadgeConsistency job. This guarantees it runs only once after all
      # badges have been granted.
      if Discourse.redis.decr("grant_badge_remaining") <= 0
        Discourse.redis.del("grant_badge_remaining")
        Jobs.enqueue(:ensure_badge_consistency)
      end
    end
  end
end
