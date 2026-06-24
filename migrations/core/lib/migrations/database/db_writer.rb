# frozen_string_literal: true

module Migrations
  module Database
    # Owns the `Connection` of the IntermediateDB for a whole conversion run and
    # writes to it directly on the caller's thread.
    #
    # Steps run sequentially and each has a single IntermediateDB producer (the
    # main thread for serial and plain `execute` steps, the collector thread for
    # parallel steps), so there are never two concurrent writers and no
    # cross-thread serialization is needed. Fork safety comes from the
    # `Connection`'s own before/after-fork hooks; the single producer is the
    # thread driving the fork and is never mid-insert when the before-fork hook
    # runs.
    #
    # `insert`, `flush` and `close` are no-ops in forked child processes, where
    # workers write through an `OfflineConnection` instead.
    class DbWriter
      class ClosedError < StandardError
      end

      def initialize(path:)
        @owner_pid = Process.pid
        @closed = false
        @error = nil
        @connection = Connection.new(path:)
      end

      def insert(sql, parameters = [])
        return if Process.pid != @owner_pid

        check_open!
        raise @error if @error

        begin
          @connection.insert(sql, parameters)
        rescue StandardError => e
          # A failed statement aborts the run, just like today's inline path.
          # Storing it keeps later calls failing fast instead of writing into a
          # broken transaction. Single producer, so the bare flag is safe.
          @error ||= e
          raise
        end
        nil
      end

      # No-op in direct mode: every `insert` has already executed. Kept so a
      # caller can issue a uniform barrier regardless of how the writer works.
      def flush
        return if Process.pid != @owner_pid

        check_open!
        raise @error if @error
        nil
      end

      def close
        return if Process.pid != @owner_pid
        return if @closed

        @closed = true
        @connection.close
        raise @error if @error
        nil
      end

      def closed?
        @closed
      end

      private

      def check_open!
        raise ClosedError, "`DbWriter` is closed" if @closed
      end
    end
  end
end
