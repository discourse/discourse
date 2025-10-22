require 'holidays/errors'

module Holidays
  module Definition
    module Context
      class FunctionProcessor
        def initialize(custom_methods_repo, proc_result_cache_repo)
          @custom_methods_repo = custom_methods_repo
          @proc_result_cache_repo = proc_result_cache_repo
        end

        def call(input, func_id, desired_func_args, func_modifier = nil)
          validate!(input, func_id, desired_func_args)

          function = @custom_methods_repo.find(func_id)
          raise Holidays::FunctionNotFound.new("Unable to find function with id '#{func_id}'") if function.nil?

          calculate(input, function, parse_arguments(input, desired_func_args), func_modifier)
        end

        private

        VALID_ARGUMENTS = [:year, :month, :day, :date, :region]

        def validate!(input, func_id, desired_func_args)
          raise ArgumentError if desired_func_args.nil? || desired_func_args.empty?

          desired_func_args.each do |name|
            raise ArgumentError unless VALID_ARGUMENTS.include?(name)
          end

          raise ArgumentError if desired_func_args.include?(:year) && !input[:year].is_a?(Integer)
          raise ArgumentError if desired_func_args.include?(:month) && (input[:month] < 0 || input[:month] > 12)
          raise ArgumentError if desired_func_args.include?(:day) && (input[:day] < 1 || input[:day] > 31)
          raise ArgumentError if desired_func_args.include?(:region) && !input[:region].is_a?(Symbol)
        end

        def parse_arguments(input, target_args)
          args = []

          if target_args.include?(:year)
            args << input[:year]
          end

          if target_args.include?(:month)
            args << input[:month]
          end

          if target_args.include?(:day)
            args << input[:day]
          end

          if target_args.include?(:date)
            args << Date.civil(input[:year], input[:month], input[:day])
          end

          if target_args.include?(:region)
            args << input[:region]
          end

          args
        end

        def calculate(input, id, args, modifier)
          result = @proc_result_cache_repo.lookup(id, *args)
          if result.kind_of?(Date)
            if modifier
              result = result + modifier # NOTE: This could be a positive OR negative number.
            end
          elsif result.is_a?(Integer)
            begin
              result = Date.civil(input[:year], input[:month], result)
            rescue ArgumentError
              raise Holidays::InvalidFunctionResponse.new("invalid day response from custom method call resulting in invalid date. Result: '#{result}'")
            end
          elsif result.nil?
            # Do nothing. This is because some functions can return 'nil' today.
            # I want to change this and so rather than come up with a clean
            # implementation I'll do this so we don't throw an error in this specific
            # situation. This should be removed once we have changed the existing
            # custom definition functions. See https://github.com/holidays/holidays/issues/204
          else
            raise Holidays::InvalidFunctionResponse.new("invalid response from custom method call, must be a 'date' or 'integer' representing the day. Result: '#{result}'")
          end

          result
        end
      end
    end
  end
end
