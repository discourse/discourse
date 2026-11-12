# frozen_string_literal: true

# special object that can be used to cancel completions and http requests
module DiscourseAi
  module Completions
    class CancelManager
      MIN_TRANSPORT_TIMEOUT = 0.1

      attr_reader :cancelled
      attr_reader :callbacks

      # @param timeout [Numeric, nil] seconds after which transports should give up;
      #   endpoints bound their own network timeouts by what remains.
      def initialize(timeout: nil)
        @deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout if timeout
        @cancelled = false
        @cancel_event = Concurrent::Event.new
        @callbacks = Concurrent::Array.new
        @mutex = Mutex.new
        @monitor_thread = nil
      end

      def monitor_thread
        @mutex.synchronize { @monitor_thread }
      end

      def start_monitor(delay: 0.5, &block)
        @mutex.synchronize do
          raise "Already monitoring" if @monitor_thread
          raise "Expected a block" if !block

          db = RailsMultisite::ConnectionManagement.current_db
          @stop_monitor = false

          @monitor_thread =
            Thread.new do
              loop do
                done = false
                @mutex.synchronize { done = true if @stop_monitor }
                break if done
                sleep delay
                @mutex.synchronize { done = true if @stop_monitor }
                @mutex.synchronize { done = true if cancelled? }
                break if done

                should_cancel = false
                RailsMultisite::ConnectionManagement.with_connection(db) do
                  should_cancel = block.call
                end

                @mutex.synchronize { cancel! if should_cancel }

                break if cancelled?
              end
            ensure
              @mutex.synchronize { @monitor_thread = nil }
            end
        end
      end

      def stop_monitor
        monitor_thread = nil

        @mutex.synchronize { monitor_thread = @monitor_thread }

        if monitor_thread
          @mutex.synchronize { @stop_monitor = true }
          # so we do not deadlock
          monitor_thread.wakeup
          monitor_thread.join(2)
          # should not happen
          if monitor_thread.alive?
            Rails.logger.warn("DiscourseAI: CancelManager monitor thread did not stop in time")
            monitor_thread.kill if monitor_thread.alive?
          end
          @monitor_thread = nil
        end
      end

      def cancelled?
        @cancelled
      end

      def remaining_seconds
        return if !@deadline
        [@deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC), 0].max
      end

      def expired?
        remaining_seconds&.zero? || false
      end

      # Caps a transport timeout so it cannot outlive the deadline.
      def bound_timeout(timeout)
        remaining = remaining_seconds
        remaining ? [timeout, [remaining, MIN_TRANSPORT_TIMEOUT].max].min : timeout
      end

      def add_callback(cb)
        @callbacks << cb
      end

      def wait_for_cancel(timeout)
        @cancel_event.wait(timeout)
      end

      def remove_callback(cb)
        @callbacks.delete(cb)
      end

      def cancel!
        @cancelled = true
        @cancel_event.set
        monitor_thread = @monitor_thread
        if monitor_thread && monitor_thread != Thread.current
          monitor_thread.wakeup
          monitor_thread.join(2)
          if monitor_thread.alive?
            Rails.logger.warn("DiscourseAI: CancelManager monitor thread did not stop in time")
            monitor_thread.kill if monitor_thread.alive?
          end
        end
        @callbacks.each do |cb|
          cb.call
        rescue StandardError
          # ignore cause this may have already been cancelled
        end
      end
    end
  end
end
