# frozen_string_literal: true

module Sidekiq
  class SuppressUserEmailErrors
    def call(worker, job, queue)
      yield
    rescue => e
      # Only suppress email errors from Jobs::UserEmail, and only for the first 3 retries
      if worker.class == Jobs::UserEmail && job["retry_count"] < 3
        raise Jobs::HandledExceptionWrapper.new(e)
      end

      raise e
    end
  end
end
