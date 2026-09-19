module Holidays
  module Finder
    module Context
      class YearHoliday
        def initialize(definition_search, dates_driver_builder, options_parser)
          @definition_search = definition_search
          @dates_driver_builder = dates_driver_builder
          @options_parser = options_parser
        end

        def call(from_date, options)
          validate!(from_date)

          regions, observed, informal = @options_parser.call(options)

          # This could be smarter but I don't have any evidence that just checking for
          # the next 12 months will cause us issues. If it does we can implement something
          # smarter here to check in smaller increments.
          #
          #FIXME Could this be until the to_date instead? Save us some processing?
          #      This is matching what was in holidays.rb currently so I'm keeping it. -pp
          dates_driver = @dates_driver_builder.call(from_date, from_date >> 12)

          to_date = Date.civil(from_date.year, 12, 31)
          holidays = []
          ret_holidays = []
          opts = gather_options(observed, informal)

          ret_holidays = @definition_search.call(dates_driver, regions, opts)

          ret_holidays.each do |holiday|
            if holiday[:date] >= from_date && holiday[:date] <= to_date
              holidays << holiday
            end
          end

          holidays.sort{|a, b| a[:date] <=> b[:date] }
        end

        private

        def validate!(from_date)
          raise ArgumentError unless from_date && from_date.is_a?(Date)
        end

        def gather_options(observed, informal)
          opts = []

          opts << :observed if observed == true
          opts << :informal if informal == true

          opts
        end
      end
    end
  end
end
