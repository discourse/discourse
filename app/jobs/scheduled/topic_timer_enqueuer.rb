# frozen_string_literal: true

module Jobs

  # Runs periodically to look through topic timers that are ready to execute,
  # and enqueues their related jobs.
  #
  # Any leftovers will be caught in the next run, because execute_at will
  # be < now, and topic timers that have run are deleted on completion or
  # otherwise have their execute_at time modified.
  class TopicTimerEnqueuer < ::Jobs::Scheduled
    every 1.minute

    def execute(_args = nil)
      TopicTimer.pending_timers.find_each do |timer|

        # the typed job may not enqueue if it has already
        # been scheduled with enqueue_at
        begin
          timer.enqueue_typed_job
        rescue => err
          Rails.logger.error("Error when attempting to enqueue topic timer job for timer #{timer.id}: #{err.class} #{err.message}: #{err.backtrace.join("\n")}")
        end
      end
    end
  end
end
