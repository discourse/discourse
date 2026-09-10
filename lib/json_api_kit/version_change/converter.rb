# frozen_string_literal: true

module JsonApiKit
  class VersionChange
    class Converter
      class Failure < StandardError
        attr_reader :names

        def initialize(names)
          @names = names
          super("cannot convert the value of #{names.join(", ")}")
        end

        def convert_names(&) = self.class.new(names.flat_map(&))
      end

      def initialize(direction, callable, names)
        @direction = direction
        @callable = callable
        @names = names
        verify!
      end

      def call(*values)
        callable.call(*values)
      rescue StandardError
        raise Failure.new(names)
      end

      private

      attr_reader :direction, :callable, :names

      def verify!
        raise ArgumentError, "#{direction}: must respond to call" unless callable.respond_to?(:call)
        return if arity.negative? || arity == names.size
        raise ArgumentError,
              "#{direction}: must take #{names.size} #{"value".pluralize(names.size)}"
      end

      def arity = callable.try(:arity) || callable.method(:call).arity
    end
  end
end
