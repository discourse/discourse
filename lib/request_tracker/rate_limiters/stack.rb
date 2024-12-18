# frozen_string_literal: true

module RequestTracker
  module RateLimiters
    class Stack
      def initialize
        @rate_limiter_klasses = []
      end

      def use(rate_limiter_klass)
        @rate_limiter_klasses << rate_limiter_klass
      end

      def delete(rate_limiter_klass)
        @rate_limiter_klasses.delete_at(get_rate_limiter_index(rate_limiter_klass))
      end

      def insert_before(existing_rate_limiter_klass, new_rate_limiter_klass)
        @rate_limiter_klasses.insert(
          get_rate_limiter_index(existing_rate_limiter_klass),
          new_rate_limiter_klass,
        )
      end

      def insert_after(existing_rate_limiter_klass, new_rate_limiter_klass)
        @rate_limiter_klasses.insert(
          get_rate_limiter_index(existing_rate_limiter_klass) + 1,
          new_rate_limiter_klass,
        )
      end

      def active_rate_limiter(request, cookie)
        @rate_limiter_klasses.each do |rate_limiter_klass|
          rate_limiter = rate_limiter_klass.new(request, cookie)
          return rate_limiter if rate_limiter.active?
        end
        nil
      end

      private

      def get_rate_limiter_index(rate_limiter_klass)
        @rate_limiter_klasses.index { |klass| klass == rate_limiter_klass }
        raise "Rate limiter #{rate_limiter_klass} not found" if index.nil?
      end
    end
  end
end
