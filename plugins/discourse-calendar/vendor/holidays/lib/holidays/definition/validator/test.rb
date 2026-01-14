module Holidays
  module Definition
    module Validator
      class Test
        def valid?(t)
          valid_dates?(t[:dates]) &&
            valid_regions?(t[:regions]) &&
            valid_name?(t[:name]) &&
            valid_holiday?(t[:holiday]) &&
            valid_options?(t[:options]) &&
            required_fields?(t)
        end

        private

        def valid_dates?(dates)
          return false unless dates

          dates.all? do |d|
            begin
              DateTime.parse(d)
              true
            rescue TypeError, ArgumentError
              false
            end
          end
        end

        def valid_regions?(regions)
          return false unless regions

          regions.all? do |r|
            r.is_a?(String)
          end
        end

        # Can be missing
        def valid_name?(n)
          return true unless n
          n.is_a?(String)
        end

        # Can be missing
        def valid_holiday?(h)
          return true unless h
          h.is_a?(TrueClass)
        end

        # Okay to be missing and can be either string or array of strings
        def valid_options?(options)
          return true unless options

          if options.is_a?(Array)
            options.all? do |o|
              o.is_a?(String)
            end
          elsif options.is_a?(String)
            true
          else
            false
          end
        end

        def required_fields?(t)
          return false if t[:name].nil? && t[:holiday].nil?
          true
        end
      end
    end
  end
end
