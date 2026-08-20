require_relative 'error'

module Definitions
  module Validation
    class Month
      def call(months)
        raise Errors::NoMonths.new("Months is required, received: '#{months}'") if months.nil? || months.empty?

        months.each do |month, month_defs|
          raise Errors::InvalidMonth.new("All months must be an integer, received: #{months}") unless month.is_a?(Integer)
          raise Errors::InvalidMonth.new("All months must be between 0 and 12, received: #{months}") if month < 0 || month > 12

          month_defs.each do |month_def|
            raise Errors::InvalidMonth.new("All months must have a name, received: #{months}") if month_def['name'].nil? || month_def['name'].empty?

            raise Errors::InvalidRegions.new("A month must contain at least one region, received: #{months}") if month_def['regions'].nil? || month_def['regions'].empty?

            month_def['regions'].each do |region|
              raise Errors::InvalidRegions.new("A month must contain at least one region, received: #{months}") if region.nil? || region.empty?
            end

            if month_def.key?("year_ranges")
              raise Errors::InvalidMonth.new("year_ranges only supports a single selector at this time, received: #{months}") unless month_def["year_ranges"].is_a?(Hash) && month_def["year_ranges"].size == 1

              selector = month_def["year_ranges"].keys.first
              value = month_def["year_ranges"][selector]

              raise Errors::InvalidMonth.new("The :year_ranges value only accepts the following: :until, :from, :limited, :between, received: #{months}") unless [:until, :from, :limited, :between].include?(selector.to_sym)

              case selector
              when "until"
                raise Errors::InvalidMonth.new("The year_ranges.until value must contain a single 'year' integer, ex. 2018, received: #{months}") unless value.is_a?(Integer)
              when "from"
                raise Errors::InvalidMonth.new("The year_ranges.from value must contain a single 'year' integer, ex. 2018, received: #{months}") unless value.is_a?(Integer)
              when "limited"
                raise Errors::InvalidMonth.new("The year_ranges.limited value must contain an array of 'year' integers, ex. [2018], received: #{months}") unless value.is_a?(Array)

                value.each do |j|
                  raise Errors::InvalidMonth.new("The year_ranges.limited value must contain an array of 'year' integers, ex. [2018], received: #{months}") unless j.is_a?(Integer)
                end
              when "between"
                raise Errors::InvalidMonth.new("year_ranges.between must contain both a 'start' and 'end' key, received: #{months}") unless value.is_a?(Hash) && value.key?("start") && value.key?("end")

                raise Errors::InvalidMonth.new("The year_ranges.between.start value must contain a single 'year' integer, ex. 2018, received: #{months}") unless value["start"].is_a?(Integer)
                raise Errors::InvalidMonth.new("The year_ranges.between.end value must contain a single 'year' integer, ex. 2018, received: #{months}") unless value["end"].is_a?(Integer)

                raise Errors::InvalidMonth.new("The year_ranges.between.end value cannot be before the start value, received: #{months}") if value["end"] < value["start"]
                raise Errors::InvalidMonth.new("The year_ranges.between start and end values cannot be the same, received: #{months}") if value["end"] == value["start"]
              end
            end
          end
        end

        true
      end
    end
  end
end
