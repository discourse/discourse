module Holidays
  module Finder
    module Context
      class Search
        def initialize(holidays_by_month_repo, custom_method_processor, day_of_month_calculator, rules)
          @holidays_by_month_repo = holidays_by_month_repo
          @custom_method_processor = custom_method_processor
          @day_of_month_calculator = day_of_month_calculator
          @rules = rules
        end

        def call(dates_driver, regions, options)
          validate!(dates_driver)

          holidays = []
          dates_driver.each do |year, months|
            months.each do |month|
              next unless hbm = @holidays_by_month_repo.find_by_month(month)
              hbm.each do |h|
                next if informal_type?(h[:type]) && !informal_set?(options)
                next unless @rules[:in_region].call(regions, h[:regions])

                if h[:year_ranges]
                  next unless @rules[:year_range].call(year, h[:year_ranges])
                end

                date = build_date(year, month, h)
                next unless date

                if observed_set?(options) && h[:observed]
                  date = build_observed_date(date, regions, h)
                end

                holidays << {:date => date, :name => h[:name], :regions => h[:regions]}
              end
            end
          end

          holidays
        end

        private

        def validate!(dates_driver)
          #FIXME This should give some kind of error message that indicates the
          #      problem.
          raise ArgumentError if dates_driver.nil? || dates_driver.empty?

          dates_driver.each do |year, months|
            months.each do |month|
              raise ArgumentError unless month >= 0 && month <= 12
            end
          end
        end

        def informal_type?(type)
          type && [:informal, 'informal'].include?(type)
        end

        def informal_set?(options)
          options && options.include?(:informal) == true
        end

        def observed_set?(options)
          options && options.include?(:observed) == true
        end

        def build_date(year, month, h)
          if h[:function]
            holiday = custom_holiday(year, month, h)
            #FIXME The result should always be present, see https://github.com/holidays/holidays/issues/204 for more information
            current_month = holiday&.month
            current_day = holiday&.mday
          else
            current_month = month
            current_day = h[:mday] || @day_of_month_calculator.call(year, month, h[:week], h[:wday])
          end

          # Silently skip bad mdays
          #TODO Should we be doing something different here? We have no concept of logging right now. Maybe we should add it?
          Date.civil(year, current_month, current_day) rescue nil
        end

        def custom_holiday(year, month, h)
          @custom_method_processor.call(
            build_custom_method_input(year, month, h[:mday], h[:regions]),
            h[:function], h[:function_arguments], h[:function_modifier],
          )
        end

        def build_custom_method_input(year, month, day, regions)
          {
            year: year,
            month: month,
            day: day,
            region: regions.first, #FIXME This isn't ideal but will work for our current use case...
          }
        end

        def build_observed_date(date, regions, h)
          @custom_method_processor.call(
            build_custom_method_input(date.year, date.month, date.day, regions),
            h[:observed],
            [:date],
          )
        end
      end
    end
  end
end
