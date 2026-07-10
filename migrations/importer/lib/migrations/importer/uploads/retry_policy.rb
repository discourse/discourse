# frozen_string_literal: true

module Migrations
  module Importer
    module Uploads
      # Decides which failures are worth retrying. The old code retried every
      # failure three times, which re-ran full ImageMagick pipelines for things
      # that will never succeed (validation errors, missing files, corrupt
      # images). Here only the errors that are actually transient — S3 hiccups,
      # network timeouts, deadlocks, a duplicate-key race — get retried, with
      # jittered exponential backoff. Everything else propagates on the first try
      # so the caller can record it and move on.
      #
      # The transient error classes are injected rather than referenced here so
      # the policy stays free of Rails/AWS constants and can be unit-tested on its
      # own.
      class RetryPolicy
        DEFAULT_MAX_ATTEMPTS = 3
        DEFAULT_BASE_DELAY = 0.5
        DEFAULT_JITTER = 0.25

        def initialize(
          transient_errors:,
          max_attempts: DEFAULT_MAX_ATTEMPTS,
          base_delay: DEFAULT_BASE_DELAY,
          jitter: DEFAULT_JITTER,
          sleeper: nil,
          rng: nil
        )
          @transient_errors = transient_errors
          @max_attempts = max_attempts
          @base_delay = base_delay
          @jitter = jitter
          @sleeper = sleeper || method(:sleep)
          @rng = rng || Random
        end

        def transient?(error)
          @transient_errors.any? { |klass| error.is_a?(klass) }
        end

        # 0.5s, 1s, 2s, … plus a little jitter so a burst of workers that all hit
        # the same transient error don't retry in lockstep.
        def backoff(attempt)
          @base_delay * (2**attempt) + @rng.rand(@jitter)
        end

        # Runs the block, retrying transient failures up to `max_attempts` times.
        #
        # `recover` maps an error class to a handler that gets first refusal: on a
        # matching error, if the handler returns a truthy value that becomes the
        # result and no retry happens. This is how the duplicate-sha1 race is
        # handled — instead of re-running the whole upload we look up the row the
        # other worker just inserted. A handler returning nil falls through to the
        # normal transient/permanent decision.
        #
        # Permanent errors, and transient ones past the attempt budget, are
        # re-raised for the caller to record.
        def run(recover: {})
          attempt = 0

          begin
            yield
          rescue StandardError => e
            handler = handler_for(recover, e)
            recovered = handler&.call(e)
            return recovered if recovered

            raise unless transient?(e) && attempt < @max_attempts

            @sleeper.call(backoff(attempt))
            attempt += 1
            retry
          end
        end

        private

        def handler_for(recover, error)
          recover.find { |klass, _handler| error.is_a?(klass) }&.last
        end
      end
    end
  end
end
