# frozen_string_literal: true

# special object that can be used to cancel completions and http requests
module DiscourseAi
  module Completions
    class CancelManager
      attr_reader :cancelled
      attr_reader :callbacks

      def initialize
        @cancelled = false
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
              begin
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

      def add_callback(cb)
        @callbacks << cb
      end

      def remove_callback(cb)
        @callbacks.delete(cb)
      end

      def cancel!
        @cancelled = true
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
          begin
            cb.call
          rescue StandardError
            # ignore cause this may have already been cancelled
          end
        end
      end
    end
  end
end
