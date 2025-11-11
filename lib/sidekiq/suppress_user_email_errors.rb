# frozen_string_literal: true

module Sidekiq
  class SuppressUserEmailErrors
    def call(worker, job, queue)
      yield
    rescue => e
      # Only suppress logging for UserEmail jobs on early retries
      if worker.class.name == "Jobs::UserEmail"
        retry_count = job["retry_count"] || 0

        if retry_count < 3
          # Wrap in HandledExceptionWrapper to suppress logging
          # but still raise so Sidekiq retries
          wrapped = Jobs::HandledExceptionWrapper.new(e)
          raise wrapped
        end
      end

      # For other jobs or retry_count >= 3, raise original exception
      raise e
    end
  end
end
