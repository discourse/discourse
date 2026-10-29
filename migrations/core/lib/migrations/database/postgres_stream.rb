# frozen_string_literal: true

module Migrations
  module Database
    # Reserve the protocol once per query. Block iteration yields directly; only
    # external iteration needs a Fiber to suspend the native result loop.
    class PostgresStream
      include Enumerable

      attr_reader :column_count

      def initialize(connection, sql, params, arrays: false)
        @pid = Process.pid
        @connection = connection
        @arrays = arrays
        @closed = false
        @native = connection.checkout(self)
        begin
          @native.send_query_params(sql, params)
          @native.set_single_row_mode
          @result = @native.get_result
          @column_count = @result ? @result.nfields : 0
        rescue Exception
          close
          raise
        end
      end

      def next
        check_owner!
        raise StopIteration if @closed
        @fiber ||= Fiber.new { each_row { |row| Fiber.yield(row) } }
        value = @fiber.resume
        raise StopIteration if @closed
        value
      end

      def each(&block)
        return enum_for(:each) unless block
        check_owner!
        return self if @closed
        if @fiber
          loop { yield self.next }
        else
          each_row(&block)
        end
        self
      ensure
        close if block
      end

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
          @result = @native.get_result
        end
      ensure
        drain
      end

      def drain
        @result&.clear
        while (pending = @native.get_result)
          pending.clear
        end
      ensure
        @closed = true
        @connection.checkin
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
