# frozen_string_literal: true

module Jobs
  class AdminProblems < ::Jobs::Scheduled
    every 30.minutes

    def execute(args)
      Notification.where(notification_type: Notification.types[:admin_problems]).destroy_all

      if persistent_problems?
        Group[:admins].users.each do |user|
          Notification.create!(
            notification_type: Notification.types[:admin_problems],
            user_id: user.id,
            data: "{}",
          )
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
