# frozen_string_literal: true

module Jobs
  class DashboardStats < ::Jobs::Scheduled
    every 30.minutes

    def execute(args)
      if persistent_problems?
        # If there have been problems reported on the dashboard for a while,
        # send a message to admins no more often than once per week.
        group_message =
          GroupMessage.new(Group[:admins].name, :dashboard_problems, limit_once_per: 7.days.to_i)
        Topic.transaction do
          group_message.delete_previous!
          group_message.create
        end
      end
    end

    private

    def persistent_problems?
      problems_started_at = AdminDashboardData.problems_started_at
      problems_started_at && problems_started_at < 2.days.ago
    end
  end
end
