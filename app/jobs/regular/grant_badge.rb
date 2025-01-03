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
    end
  end
end
