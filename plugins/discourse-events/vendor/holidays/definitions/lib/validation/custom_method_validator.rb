require_relative 'error'

module Definitions
  module Validation
    class CustomMethod
      VALID_ARGUMENTS = ["date", "year", "month", "day"]

      def call(methods)
        methods.each do |name, method|
          raise Errors::InvalidCustomMethod unless
          valid_name?(name) &&
            valid_arguments?(method['arguments']) &&
            valid_source?(method['ruby'])
        end

        true
      end

      private

      def valid_name?(name)
        !name.nil? && !name.empty?
      end

      def valid_arguments?(arguments)
        !arguments.nil? &&
          !arguments.empty? &&
          arguments.split(",").all? { |arg|
            arg == arg.chomp && VALID_ARGUMENTS.include?(arg.strip)
          }
      end

      def valid_source?(source)
        !source.nil? && !source.empty?
      end
    end
  end
end
