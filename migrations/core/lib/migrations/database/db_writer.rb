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
        @resume_condvar = ConditionVariable.new
        @paused = false
        @error = nil
        @closed = false

        # Hook registration order is load-bearing: `ForkManager` runs hooks in
        # registration order, so the writer thread parks before the connection's
        # own before-fork hook closes the database, and the connection is
        # reopened before the writer resumes.
        @pause_hook = ForkManager.before_fork { pause }
        @connection = Connection.new(path:)
        @resume_hook = ForkManager.after_fork_parent { resume }

        @thread = start_writer_thread
      end

      def insert(sql, parameters = [])
        return if Process.pid != @owner_pid
        raise_if_closed!
        raise_pending_error!

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
        raise_if_closed!
        raise_pending_error!
        @mutex.synchronize do
          raise ThreadError, "`flush` cannot be called while paused for a fork" if @paused
        end

        request = FlushRequest.new(Queue.new)
        @queue.push(request)
        request.done.pop

        raise_pending_error!
        nil
      end

      def close
        return if Process.pid != @owner_pid

        @mutex.synchronize do
          return if @closed
          @closed = true

          # unpark the writer thread in case `close` happens while paused
          @paused = false
          @resume_condvar.broadcast
        end

        @queue.close
        @thread.join
        @connection.close

        ForkManager.remove_before_fork_hook(@pause_hook)
        ForkManager.remove_after_fork_parent_hook(@resume_hook)

        raise_pending_error!
        nil
      end

      def closed?
        @mutex.synchronize { @closed }
      end

      private

      FlushRequest = Struct.new(:done)
      ParkRequest = Struct.new(:acknowledged)

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
        # on their next `insert`, `flush` or `close` call.
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
      def pause
        @mutex.synchronize do
          return if @closed
          @paused = true
        end

        request = ParkRequest.new(Queue.new)
        @queue.push(request)
        request.acknowledged.pop
      end

      def resume
        @mutex.synchronize do
          @paused = false
          @resume_condvar.broadcast
        end
      end

      def park_until_resumed(request)
        @mutex.synchronize do
          request.acknowledged.push(true)
          @resume_condvar.wait(@mutex) while @paused
        end
      end

      def raise_if_closed!
        raise ClosedError, "`DbWriter` is closed" if @closed
      end

      def raise_pending_error!
        if (error = @error)
          raise WriteError, "Writing to the database failed", cause: error
        end
      end
    end
  end
end
