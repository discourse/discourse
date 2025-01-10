# frozen_string_literal: true

# This job is deprecated and will be removed in the future. The only reason it exists is for clean up purposes.
module Jobs
  # used to ensure at least 1 sidekiq is running correctly
  class Heartbeat < ::Jobs::Scheduled
    every 24.hours

    def execute(args)
      ::Jobs.enqueue(:run_heartbeat, {})
    end
  end
end
