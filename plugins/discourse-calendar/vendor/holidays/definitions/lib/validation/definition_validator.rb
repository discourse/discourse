require_relative 'error'

module Definitions
  module Validation
    class Definition
      def initialize(custom_method_validator, months_validator, test_validator)
        @custom_method_validator = custom_method_validator
        @months_validator = months_validator
        @test_validator = test_validator
      end

      def call(definition)
        validate_months!(definition['months'])
        validate_methods!(definition['methods'])
        validate_tests!(definition['tests'])

        true
      end

      private

      def validate_months!(months)
        @months_validator.call(months)
      end

      def validate_methods!(methods)
        @custom_method_validator.call(methods) unless methods.nil?
      end

      def validate_tests!(tests)
        @test_validator.call(tests) unless tests.nil?
      end
    end
  end
end
