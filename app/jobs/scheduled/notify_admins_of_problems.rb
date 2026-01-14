# frozen_string_literal: true

module Jobs
  class NotifyAdminsOfProblems < ::Jobs::Scheduled
    every 30.minutes

    def execute(_args)
      Notification
        .where(notification_type: Notification.types[:admin_problems])
        .where("created_at < ?", 7.days.ago)
        .destroy_all

      return if !persistent_problems?

      notified_user_ids =
        Notification.where(notification_type: Notification.types[:admin_problems]).pluck(:user_id)

      users = Group[:admins].users.where.not(id: notified_user_ids)

      users.each do |user|
        Notification.create!(
          notification_type: Notification.types[:admin_problems],
          user_id: user.id,
          data: "{}",
        )
      end
    end

    private

    def persistent_problems?
      ProblemCheckTracker.where(
        "last_problem_at > last_success_at AND last_success_at < ?",
        2.days.ago,
      ).exists?
    end
  end
end
