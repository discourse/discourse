module Holidays
  module Definition
    module Validator
      class CustomMethod
        VALID_ARGUMENTS = ["date", "year", "month", "day", "region"]

        def valid?(m)
          valid_name?(m[:name]) &&
            valid_arguments?(m[:arguments]) &&
            valid_source?(m[:source])
        end

        private

        def valid_name?(name)
          !name.nil? && !name.empty?
        end

        def valid_arguments?(arguments)
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
end
