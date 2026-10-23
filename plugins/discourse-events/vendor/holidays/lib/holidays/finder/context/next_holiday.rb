module Holidays
  module Finder
    module Context
      class NextHoliday
        def initialize(definition_search, dates_driver_builder, options_parser)
          @definition_search = definition_search
          @dates_driver_builder = dates_driver_builder
          @options_parser = options_parser
        end

        def call(holidays_count, from_date, options)
          validate!(holidays_count, from_date)

          regions, observed, informal = @options_parser.call(options)

          holidays = []
          opts = gather_options(observed, informal)

          # This could be smarter but I don't have any evidence that just checking for
          # the next 12 months will cause us issues. If it does we can implement something
          # smarter here to check in smaller increments.
          dates_driver = @dates_driver_builder.call(from_date, from_date >> 12)

          @definition_search
            .call(dates_driver, regions, opts)
            .sort_by { |a| a[:date] }
            .each do |holiday|
              if holiday[:date] >= from_date
                holidays << holiday
                holidays_count -= 1
                break if holidays_count == 0
              end
            end

          holidays.sort_by { |a| a[:date] }
        end

        private

        def validate!(holidays_count, from_date)
          raise ArgumentError unless holidays_count
          raise ArgumentError if holidays_count <= 0
          raise ArgumentError unless from_date
        end

        def gather_options(observed, informal)
          opts = []

          opts << :observed if observed
          opts << :informal if informal

          opts
        end
      end
    end
  end
end
