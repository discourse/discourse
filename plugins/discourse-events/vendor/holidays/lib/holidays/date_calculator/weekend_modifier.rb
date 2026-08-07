module Holidays
  module DateCalculator
    class WeekendModifier
      # Move date to Monday if it occurs on a Saturday on Sunday.
      # Does not modify date if it is not a weekend.
      # Used as a callback function.
      def to_monday_if_weekend(date)
        return date unless date.wday == 6 || date.wday == 0
        to_next_weekday(date)
      end

      # Move date to Monday if it occurs on a Sunday.
      # Does not modify the date if it is not a Sunday.
      # Used as a callback function.
      def to_monday_if_sunday(date)
        return date unless date.wday == 0
        to_next_weekday(date)
      end

      # Move Boxing Day if it falls on a weekend, leaving room for Christmas.
      # Used as a callback function.
      def to_weekday_if_boxing_weekend(date)
        if date.wday == 6 || date.wday == 0
          date += 2
        elsif date.wday == 1 # https://github.com/holidays/holidays/issues/27
          date += 1
        end

        date
      end

      # if Christmas falls on a Saturday, move it to the next Monday (Boxing Day will be Sunday and potentially Tuesday)
      # if Christmas falls on a Sunday, move it to the next Tuesday (Boxing Day will go on Monday)
      #
      # if Boxing Day falls on a Saturday, move it to the next Monday (Christmas will go on Friday)
      # if Boxing Day falls on a Sunday, move it to the next Tuesday (Christmas will go on Saturday & Monday)
      def to_tuesday_if_sunday_or_monday_if_saturday(date)
        date += 2 if [0, 6].include?(date.wday)
        date
      end

      # Call to_weekday_if_boxing_weekend but first get date based on year
      # Used as a callback function.
      def to_weekday_if_boxing_weekend_from_year_or_to_tuesday_if_monday(year)
        to_weekday_if_boxing_weekend(Date.civil(year, 12, 26))
      end

      # Call to_weekday_if_boxing_weekend but first get date based on year
      # Used as a callback function.
      def to_weekday_if_boxing_weekend_from_year(year)
        to_tuesday_if_sunday_or_monday_if_saturday(Date.civil(year, 12, 26))
      end

      # Move date to Monday if it occurs on a Sunday or to Friday if it occurs on a
      # Saturday.
      # Used as a callback function.
      def to_weekday_if_weekend(date)
        date += 1 if date.wday == 0
        date -= 1 if date.wday == 6
        date
      end

      # Finds the next weekday. For example, if a 'Friday' date is received
      # it will return the following Monday. If Sunday then return Monday,
      # if Saturday return Monday, if Tuesday return Wednesday, etc.
      def to_next_weekday(date)
        case date.wday
        when 6
          date += 2
        when 5
          date += 3
        else
          date += 1
        end

        date
      end
    end
  end
end
