# frozen_string_literal: true

# Upstream feature request: https://github.com/rspec/rspec/issues/231

module RSpec
  module Mocks
    class MessageExpectation
      # Only apply the stub if called from the described class
      #
      # @return [MessageExpectation] self, to support chaining
      # @example
      #   allow(Process).to receive(:clock_gettime).from_described_class.and_return(123.45)
      def from_described_class
        # Mark the method double so it knows to check caller context
        @method_double.from_described_class_only = true

        self
      end
    end

    module MethodDoubleExtensions
      attr_accessor :from_described_class_only

      # Override proxy_method_invoked to check caller context before processing expectations
      def proxy_method_invoked(obj, *args, &block)
        # If this method has from_described_class_only expectations, check the caller
        if @from_described_class_only && !should_apply_stub?
          return original_implementation_callable.call(*args, &block)
        end

        # Process normally through RSpec's expectation/stub system
        super
      end
      ruby2_keywords :proxy_method_invoked if respond_to?(:ruby2_keywords, true)

      private

      def should_apply_stub?
        return false unless defined?(RSpec.current_example.metadata)

        # Find the real caller location, ignoring RSpec internals
        actual_caller =
          caller_locations.find do |location|
            path = location.path
            !path.include?("rspec-mocks") && !path.include?("rspec-core") &&
              !path.end_with?("/freedom_patches/rspec_mocks_from_described_class.rb")
          end
        return false unless actual_caller

        check_if_in_described_class(actual_caller, RSpec.current_example.metadata[:described_class])
      end

      def check_if_in_described_class(caller_location, described_class)
        lines = File.readlines(caller_location.path)
        line_idx = caller_location.lineno - 1

        # Look backwards to find the enclosing class
        while line_idx >= 0
          line = lines[line_idx]

          # Found a class definition
          return $1 == described_class.name.split("::").last if line =~ /^\s*class\s+(\w+)/

          # Stop at test boundaries
          break if line =~ /^(module|describe|context|it)\s+/

          line_idx -= 1
        end

        false
      end
    end

    class MethodDouble
      prepend MethodDoubleExtensions
    end
  end
end
