# frozen_string_literal: true

module Migrations
  module Database
    # A query keeps the connection until all rows are read or the stream is closed.
    # Block iteration runs in the current fiber. #next uses a separate fiber.
    class PostgresStream
      include Enumerable

      # Raised when a stream is consumed more than once.
      class ConsumedError < StandardError
      end

      # @return [Integer] the number of columns in the result
      attr_reader :column_count

      # @param connection [ManagedConnection]
      # @param sql [String] a query with `$1`, `$2`, … placeholders
      # @param params [Array] the values for the placeholders
      # @param arrays [Boolean] yield rows as arrays instead of hashes; a single
      #   column is yielded as its value
      # @raise [ManagedConnection::BusyError] if the connection is in use
      def initialize(connection, sql, params, arrays: false)
        @pid = Process.pid
        @managed_connection = connection
        @arrays = arrays
        @closed = false
        @postgres_connection = connection.start_operation(self)
        begin
          @postgres_connection.send_query_params(sql, params)
          @postgres_connection.set_single_row_mode
          @result = @postgres_connection.get_result
          @column_count = @result ? @result.nfields : 0
        rescue Exception
          close
          raise
        end
      end

      # @return [Hash, Array, Object] the next row
      # @raise [StopIteration] when all rows are read; the stream is closed by then
      def next
        check_owner!
        raise StopIteration if @closed
        @fiber ||= Fiber.new { each_row { |row| Fiber.yield(row) } }
        value = @fiber.resume
        raise StopIteration if @closed
        value
      end

      # @return [self]
      # @raise [ConsumedError] if the stream was consumed before
      def each(&block)
        return enum_for(:each) unless block
        check_owner!
        raise ConsumedError, "A database stream can only be consumed once" if @closed
        if @fiber
          loop { yield self.next }
        else
          each_row(&block)
        end
        self
      ensure
        close if block
      end

      # @return [void]
      def close
        check_owner!
        return if @closed
        if @fiber&.alive?
          @fiber.raise(StopIteration)
        else
          drain
        end
      rescue StopIteration
        nil
      end

      private

      def each_row(&block)
        while @result
          if @arrays && @column_count == 1
            @result.stream_each_row { |row| yield row[0] }
          elsif @arrays
            @result.stream_each_row(&block)
          else
            @result.stream_each(&block)
          end
          @result.clear
          @result = @postgres_connection.get_result
        end
      ensure
        drain
      end

      def drain
        @result&.clear
        while (pending = @postgres_connection.get_result)
          pending.clear
        end
      ensure
        @closed = true
        @managed_connection.finish_operation
      end

      def check_owner!
        if @pid != Process.pid
          raise ManagedConnection::DiscardedError,
                "Cannot consume a stream inherited from another process"
        end
      end
    end
  end
end
