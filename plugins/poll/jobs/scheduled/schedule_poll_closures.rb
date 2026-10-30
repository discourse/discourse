# frozen_string_literal: true

module Jobs
  class SchedulePollClosures < ::Jobs::Scheduled
    every 15.minutes

    def execute(args)
      ::Poll.schedule_imminent_closures
    end
  end
end
