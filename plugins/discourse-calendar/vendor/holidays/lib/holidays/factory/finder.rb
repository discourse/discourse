require 'holidays/finder/context/between'
require 'holidays/finder/context/dates_driver_builder'
require 'holidays/finder/context/next_holiday'
require 'holidays/finder/context/parse_options'
require 'holidays/finder/context/search'
require 'holidays/finder/context/year_holiday'
require 'holidays/finder/rules/in_region'
require 'holidays/finder/rules/year_range'

module Holidays
  module Factory
    module Finder
      class << self
        def search
          Holidays::Finder::Context::Search.new(
            Factory::Definition.holidays_by_month_repository,
            Factory::Definition.function_processor,
            Factory::DateCalculator.day_of_month_calculator,
            rules,
          )
        end

        def between
          Holidays::Finder::Context::Between.new(
            search,
            dates_driver_builder,
            parse_options,
          )
        end

        def next_holiday
          Holidays::Finder::Context::NextHoliday.new(
            search,
            dates_driver_builder,
            parse_options,
          )
        end

        def year_holiday
          Holidays::Finder::Context::YearHoliday.new(
            search,
            dates_driver_builder,
            parse_options,
          )
        end

        def parse_options
          Holidays::Finder::Context::ParseOptions.new(
            Factory::Definition.regions_repository,
            Factory::Definition.region_validator,
            Factory::Definition.loader,
          )
        end

        private

        def dates_driver_builder
          Holidays::Finder::Context::DatesDriverBuilder.new
        end

        def rules
          {
            :in_region => Holidays::Finder::Rules::InRegion,
            :year_range => Holidays::Finder::Rules::YearRange,
          }
        end
      end
    end
  end
end
