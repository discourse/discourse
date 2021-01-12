# frozen_string_literal: true

module Jobs

  # Runs periodically to look through topic timers that are ready to execute,
  # and enqueues their related jobs.
  #
  # Any leftovers will be caught in the next run, because execute_at will
  # be < now, and topic timers that have run are deleted on completion.
  class TopicTimerEnqueuer < ::Jobs::Scheduled
    every 5.minutes

    def execute(args = nil)
      timers = TopicTimer.pending_timers

      timers.each do |timer|

        # the typed job may not enqueue if it has already
        # been scheduled with enqueue_at
        timer.enqueue_typed_job
      end
    end
  end
end
