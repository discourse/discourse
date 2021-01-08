# frozen_string_literal: true

module Jobs
  class ProcessUserNotificationSchedules < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      UserNotificationSchedule.enabled.each do |schedule|
        UserNotificationScheduleProcessor.create_do_not_disturb_timings_for(schedule)
      end
    end
  end
end
