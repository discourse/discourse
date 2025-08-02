# frozen_string_literal: true

module RequestTracker
  module RateLimiters
    # :nodoc:
    class Stack
      def initialize
        @rate_limiter_klasses = []
      end

      def to_s
        @rate_limiter_klasses.map { |klass| klass.to_s }.join(", ")
      end

      def include?(reference_klass)
        @rate_limiter_klasses.include?(reference_klass)
      end

      def prepend(rate_limiter_klass)
        @rate_limiter_klasses.prepend(rate_limiter_klass)
      end

      def append(rate_limiter_klass)
        @rate_limiter_klasses.append(rate_limiter_klass)
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

      def method_missing(method_name, *args, &block)
        if @rate_limiter_klasses.respond_to?(method_name)
          @rate_limiter_klasses.send(method_name, *args, &block)
        else
          super
        end
      end

      private

      def get_rate_limiter_index(rate_limiter_klass)
        index = @rate_limiter_klasses.index { |klass| klass == rate_limiter_klass }
        raise "Rate limiter #{rate_limiter_klass} not found" if index.nil?
        index
      end
    end
  end
end
