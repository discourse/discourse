# frozen_string_literal: true

module Migrations
  module Database
    # Owns the `Connection` of the IntermediateDB for a whole conversion run and
    # funnels all writes through a single writer thread. `Connection#insert` is
    # not thread-safe, so the writer thread is its sole caller; producers only
    # ever enqueue.
    #
    # `insert`, `flush` and `close` are no-ops in forked child processes; workers
    # write through an `OfflineConnection` instead.
    class DbWriter
      QUEUE_SIZE = 10_000

      class ClosedError < StandardError
      end

      class WriteError < StandardError
      end

      def initialize(path:)
        @owner_pid = Process.pid
        @queue = SizedQueue.new(QUEUE_SIZE)
        @mutex = Mutex.new
        @park_request = nil
        @error = nil
        @closed = false

        # Hook registration order is load-bearing: `ForkManager` runs hooks in
        # registration order, so the writer thread parks before the connection's
        # own before-fork hook closes the database, and the connection is
        # reopened before the writer resumes.
        @pause_hook = ForkManager.before_fork { pause }

        begin
          @connection = Connection.new(path:)
          @resume_hook = ForkManager.after_fork_parent { resume }
          @thread = start_writer_thread
        rescue StandardError
          @connection&.close
          ForkManager.remove_before_fork_hook(@pause_hook)
          ForkManager.remove_after_fork_parent_hook(@resume_hook) if @resume_hook
          raise
        end
      end

      def insert(sql, parameters = [])
        return if Process.pid != @owner_pid

        @mutex.synchronize do
          check_open!
          check_error!
        end

        @queue.push([sql, parameters])
        nil
      end

      # Barrier: returns once all previously enqueued statements have been
      # executed (not necessarily committed).
      def flush
        return if Process.pid != @owner_pid
        if Thread.current == @thread
          raise ThreadError, "`flush` cannot be called from the writer thread"
        end

        @mutex.synchronize do
          check_open!
          check_error!
          raise ThreadError, "`flush` cannot be called while paused for a fork" if @park_request
        end

        request = FlushRequest.new(Queue.new)
        @queue.push(request)
        request.done.pop

        @mutex.synchronize { check_error! }
        nil
      end

      def close
        return if Process.pid != @owner_pid

        @mutex.synchronize do
          return if @closed
          @closed = true

          # unpark the writer thread in case `close` happens while paused
          @park_request&.resumed&.push(true)
          @park_request = nil
        end

        @queue.close
        @thread.join
        @connection.close

        ForkManager.remove_before_fork_hook(@pause_hook)
        ForkManager.remove_after_fork_parent_hook(@resume_hook)

        @mutex.synchronize { check_error! }
        nil
      end

      def closed?
        @mutex.synchronize { @closed }
      end

      private

      FlushRequest = Struct.new(:done)
      ParkRequest = Struct.new(:acknowledged, :resumed)

      def start_writer_thread
        Thread.new do
          Thread.current.name = "db_writer"

          # `pop` returns the remaining items and then `nil` once the queue has
          # been closed, so `close` always drains before the thread exits.
          while (item = @queue.pop)
            case item
            when ParkRequest
              park_until_resumed(item)
            when FlushRequest
              item.done.push(true)
            else
              execute(item)
            end
          end
        end
      end

      def execute(item)
        # After a failed statement the writer stops writing but keeps consuming,
        # so producers never block on a full queue; the stored error is raised
        # on their next `insert`, `flush` or `close` call. Only this thread
        # assigns `@error`, so the bare read is safe; producers read it under
        # `@mutex`.
        return if @error

        sql, parameters = item
        @connection.insert(sql, parameters)
      rescue StandardError => e
        @mutex.synchronize { @error ||= e }
      end

      # Rendezvous used by the before-fork hook: pushes a sentinel behind all
      # pending statements and blocks until the writer thread has executed them
      # and parked outside any `Connection` call. Producers may keep enqueueing
      # while paused; only consumption stops.
      #
      # The whole rendezvous is per-request — each `ParkRequest` carries its own
      # acknowledge and resume queues — so a resume can never be attributed to
      # the wrong park, no matter how closely fork windows follow each other.
      def pause
        request = ParkRequest.new(Queue.new, Queue.new)

        @mutex.synchronize do
          return if @closed
          @park_request = request
        end

        @queue.push(request)
        request.acknowledged.pop
      end

      def resume
        request = @mutex.synchronize { @park_request.tap { @park_request = nil } }
        request&.resumed&.push(true)
      end

      def park_until_resumed(request)
        request.acknowledged.push(true)
        request.resumed.pop
      end

      # Both expect `@mutex` to be held by the caller.
      def check_open!
        raise ClosedError, "`DbWriter` is closed" if @closed
      end

      def check_error!
        raise WriteError, "Writing to the database failed", cause: @error if @error
      end
    end
  end
end
