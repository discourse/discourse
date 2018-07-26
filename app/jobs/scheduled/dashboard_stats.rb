require_dependency 'admin_dashboard_data'
require_dependency 'group'
require_dependency 'group_message'

module Jobs
  class DashboardStats < Jobs::Scheduled
    every 30.minutes

    def execute(args)
      problems_started_at = AdminDashboardData.problems_started_at
      if problems_started_at && problems_started_at < 2.days.ago
        # If there have been problems reported on the dashboard for a while,
        # send a message to admins no more often than once per week.
        GroupMessage.create(Group[:admins].name, :dashboard_problems, limit_once_per: 7.days.to_i)
      end
    end
  end
end
