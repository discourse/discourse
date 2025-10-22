# This context builds a hash that contains {:year => [<array of months>]}. The idea is that
# we will iterate over each year and then over each month internally and check to see if the
# supplied dates match any holidays for the region and date. So if we supply start_date of 2015/1/1
# and end_date of 2015/6/1 then we will return a date driver of {:2015 => [0, 1, 2, 5, 6, 7]}.
# In the logic in the various other 'finder' contexts we will iterate over this and compare dates
# in these months to the supplied range to determine whether they should be returned to the user.
module Holidays
  module Finder
    module Context
      class DatesDriverBuilder
        def call(start_date, end_date)
          dates_driver = {}

          (start_date..end_date).each do |date|
            dates_driver[date.year] = [] unless dates_driver[date.year]
            dates_driver[date.year] << date.month
            dates_driver = add_border_months(date, dates_driver)
          end
          clean(dates_driver)
        end

        private

        # As part of https://github.com/holidays/holidays/issues/146 I am returning
        # additional months in an attempt to catch month-spanning date situations (i.e.
        # dates falling on 2/1 but being observed on 1/31). By including the additional months
        # we are increasing runtimes slightly but improving accuracy, which is more important
        # to me at this stage.
        def add_border_months(current_date, dates_driver)
          if current_date.month == 1
            dates_driver[current_date.year] << 2

            prev_year = current_date.year - 1
            dates_driver[prev_year] = [] unless dates_driver[prev_year]
            dates_driver[prev_year] << 12
          elsif current_date.month == 12
            dates_driver[current_date.year] << 11

            next_year = current_date.year + 1
            dates_driver[next_year] = [] unless dates_driver[next_year]
            dates_driver[next_year] << 1
          else
            dates_driver[current_date.year] << current_date.month - 1 << current_date.month + 1
          end

          dates_driver
        end

        def clean(dates_driver)
          dates_driver.each do |year, months|
            # Always add variable month '0' for proc calc purposes. For example, 'easter' lives in
            # 'month 0' but is vital to calculating a lot of easter-related dates.
            dates_driver[year] << 0

            dates_driver[year].uniq!
            dates_driver[year].sort!
          end

          dates_driver
        end
      end
    end
  end
end
