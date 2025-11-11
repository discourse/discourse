# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class PostStreamer
      # test only
      def self.on_callback=(on_callback)
        @on_callback = on_callback
      end

      def self.on_callback
        @on_callback
      end

      def initialize(delay: 0.5)
        @mutex = Mutex.new
        @callback = nil
        @delay = delay
        @done = false
      end

      def run_later(&callback)
        self.class.on_callback.call(callback) if self.class.on_callback
        @mutex.synchronize { @callback = callback }
        ensure_worker!
      end

      def finish(skip_callback: false)
        @mutex.synchronize do
          @callback&.call if skip_callback
          @callback = nil
          @done = true
        end

        begin
          @worker_thread&.wakeup
        rescue StandardError
          ThreadError
        end
        @worker_thread&.join
        @worker_thread = nil
      end

      private

      def run
        while !@done
          @mutex.synchronize do
            callback = @callback
            @callback = nil
            callback&.call
          end
          sleep @delay
        end
      end

      def ensure_worker!
        return if @worker_thread
        @mutex.synchronize do
          return if @worker_thread
          db = RailsMultisite::ConnectionManagement.current_db
          @worker_thread =
            Thread.new { RailsMultisite::ConnectionManagement.with_connection(db) { run } }
        end
      end
    end
  end
end
