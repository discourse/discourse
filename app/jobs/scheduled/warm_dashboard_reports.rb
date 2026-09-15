# frozen_string_literal: true

module Jobs
  class WarmDashboardReports < ::Jobs::Scheduled
    every 30.minutes

    STAFF_ACTIVITY_WINDOW = 7.days

    def execute(_args)
      return if !UpcomingChanges.enabled?(:dashboard_improvements)

      return if !User.human_users.staff.where("last_seen_at > ?", STAFF_ACTIVITY_WINDOW.ago).exists?

      AdminDashboardCacheWarmer.call(guardian: Discourse.system_user.guardian)
    end
  end
end
