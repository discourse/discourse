# frozen_string_literal: true

module Jobs
  class ProcessUserNotificationSchedules < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      UserNotificationSchedule
        .enabled
        .includes(:user)
        .each do |schedule|
          begin
            schedule.create_do_not_disturb_timings
          rescue => e
            Discourse.warn_exception(
              e,
              message: "Failed to process user_notification_schedule with ID #{schedule.id}",
            )
          end
        end
    end
  end
end
