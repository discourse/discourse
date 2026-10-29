# frozen_string_literal: true

module Migrations
  module Database
    # A single-pass stream with an explicit close path for partial consumption.
    # Its operation lease lasts until exhaustion, a block exits, or #close.
    class PostgresStream
      include Enumerable

      attr_reader :column_count

      def initialize(connection, sql, params, arrays: false)
        @pid = Process.pid
        @closed = false
        @fiber =
          Fiber.new do
            connection.with do |native|
              native.send_query_params(sql, params)
              native.set_single_row_mode
              result = nil
              begin
                result = native.get_result
                count = result ? result.nfields : 0
                Fiber.yield(count)
                while result
                  if arrays
                    result.stream_each_row { |row| Fiber.yield(count == 1 ? row[0] : row) }
                  else
                    result.stream_each { |row| Fiber.yield(row) }
                  end
                  result.clear
                  result = native.get_result
                end
              ensure
                result&.clear
                while (pending = native.get_result)
                  pending.clear
                end
              end
            end
          ensure
            @closed = true
          end
        @column_count = @fiber.resume
      end

      def next
        check_owner!
        raise StopIteration if @closed
        value = @fiber.resume
        raise StopIteration if @closed
        value
      end

      def each
        return enum_for(:each) unless block_given?
        loop { yield self.next }
        self
      ensure
        close if block_given?
      end

      def close
        check_owner!
        @fiber.raise(StopIteration) unless @closed
      rescue StopIteration
        nil
      end

      private

      def check_owner!
        if @pid != Process.pid
          raise ManagedConnection::DiscardedError,
                "Cannot consume a stream inherited from another process"
        end
      end
    end
  end
end
