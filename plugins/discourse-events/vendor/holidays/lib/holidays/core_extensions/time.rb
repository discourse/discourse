module Holidays
  module CoreExtensions
    module Time
      def self.included(base)
        base.extend ClassMethods
      end

      module ClassMethods
        COMMON_YEAR_DAYS_IN_MONTH = [nil, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

        # Returns the number of days in the given month.
        # If no year is specified, it will use the current year.
        def days_in_month(month, year = current.year)
          if month == 2 && ::Date.gregorian_leap?(year)
            29
          else
            COMMON_YEAR_DAYS_IN_MONTH[month]
          end
        end
      end
    end
  end
end
