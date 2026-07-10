# frozen_string_literal: true

module Migrations
  module Importer
    module Uploads
      # An adjustable semaphore that decides how many worker threads may run at
      # once. The pipeline spawns `max` workers up front and never changes that;
      # this gate is what actually throttles them. A worker calls {#acquire}
      # before each item and blocks while `active` has reached `target`, then
      # {#release} after. The {AdaptiveController} moves `target` up and down as it
      # watches CPU, memory, and throughput; a change takes effect at the next item
      # boundary, so shrinking or growing is cheap and quick without killing or
      # respawning threads.
      #
      # `target` is clamped to `[min, max]`. `min` is 1, not the controller's
      # normal floor: a memory emergency is allowed to squeeze below the floor, and
      # the gate must not undo that.
      class WorkerGate
        attr_reader :max, :min

        def initialize(target:, max:, min: 1)
          @min = min
          @max = max
          @target = target.clamp(min, max)
          @active = 0
          @waiting = 0
          @mutex = Mutex.new
          @condition = ConditionVariable.new
        end

        # Block until fewer than `target` workers are running, then count this one
        # in. Must be paired with {#release}.
        def acquire
          @mutex.synchronize do
            @waiting += 1
            begin
              @condition.wait(@mutex) while @active >= @target
            ensure
              @waiting -= 1
            end
            @active += 1
          end
        end

        # Give a permit back and wake one waiter, if any.
        def release
          @mutex.synchronize do
            @active -= 1
            @condition.signal
          end
        end

        # Move the ceiling on concurrent workers. Growing wakes parked workers so
        # they can pick up the new slots; shrinking just lets running workers drain
        # without re-admitting them. Either way it lands at the next item boundary.
        def target=(value)
          @mutex.synchronize do
            @target = value.clamp(@min, @max)
            @condition.broadcast
          end
        end

        def target
          @mutex.synchronize { @target }
        end

        def active
          @mutex.synchronize { @active }
        end

        def waiting
          @mutex.synchronize { @waiting }
        end
      end
    end
  end
end
