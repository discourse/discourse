module Holidays
  module Finder
    module Rules
      class YearRange
        class << self
          UNTIL = :until
          FROM = :from
          LIMITED = :limited
          BETWEEN = :between

          def call(target_year, year_range_defs)
            validate!(target_year, year_range_defs)

            operator = year_range_defs.keys.first
            rule_value = year_range_defs[operator]

            case operator
            when UNTIL
              matched = target_year <= rule_value
            when FROM
              matched = target_year >= rule_value
            when LIMITED
              matched = rule_value.include?(target_year)
            when BETWEEN
              matched = rule_value.cover?(target_year)
            else
              matched = false
            end

            matched
          end

          private

          def validate!(target_year, year_ranges)
            raise ArgumentError.new("target_year must be a number") unless target_year.is_a?(Integer)
            raise ArgumentError.new("year_ranges cannot be missing") if year_ranges.nil? || year_ranges.empty?
            raise ArgumentError.new("year_ranges must contain a hash with a single operator") unless year_ranges.is_a?(Hash) && year_ranges.size == 1

            operator = year_ranges.keys.first
            value = year_ranges[operator]

            raise ArgumentError.new("Invalid operator found: '#{operator}'") unless [UNTIL, FROM, LIMITED, BETWEEN].include?(operator)

            case operator
            when UNTIL, FROM
              raise ArgumentError.new("#{UNTIL} and #{FROM} operator value must be a number, received: '#{value}'") unless value.is_a?(Integer)
            when LIMITED
              raise ArgumentError.new(":limited operator value must be an array containing at least one integer value, received: '#{value}'") unless value.is_a?(Array) && value.size >= 1 && value.all? { |v| v.is_a?(Integer) }
            when BETWEEN
              raise ArgumentError.new(":between operator value must be a range, received: '#{value}'") unless value.is_a?(Range)
            end
          end
        end
      end
    end
  end
end
