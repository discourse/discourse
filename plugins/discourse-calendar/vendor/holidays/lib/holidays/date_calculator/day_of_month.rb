module Holidays
  module DateCalculator
    # Calculate day of the month based on the week number and the day of the
    # week.
    #
    # ==== Parameters
    # [<tt>year</tt>]  Integer.
    # [<tt>month</tt>] Integer from 1-12.
    # [<tt>week</tt>]  One of <tt>:first</tt>, <tt>:second</tt>, <tt>:third</tt>,
    #                  <tt>:fourth</tt>, <tt>:fifth</tt> or <tt>:last</tt>.
    # [<tt>wday</tt>]  Day of the week as an integer from 0 (Sunday) to 6
    #                  (Saturday) or as a symbol (e.g. <tt>:monday</tt>).
    #
    # Returns an integer.
    #
    # ===== Examples
    # First Monday of January, 2008:
    #   Holidays::Factory::DateCalculator.day_of_month_calculator.call(2008, 1, :first, :monday)
    #   => 7
    #
    # Third Thursday of December, 2008:
    #   Holidays::Factory::DateCalculator.day_of_month_calculator.call(2008, 12, :third, :thursday)
    #   => 18
    #
    # Last Monday of January, 2008:
    #   Holidays::Factory::DateCalculator.day_of_month_calculator.call(2008, 1, :last, 1)
    #   => 28
    #--
    # see http://www.irt.org/articles/js050/index.htm
    class DayOfMonth
      def call(year, month, week, wday)
        raise ArgumentError, "Week parameter must be one of Holidays::WEEKS (provided #{week})." unless weeks.include?(week) or weeks.has_value?(week)

        unless wday.kind_of?(Numeric) and wday.between?(0,6) or day_symbols.index(wday)
          raise ArgumentError, "Wday parameter must be an integer between 0 and 6 or one of Holidays::DAY_SYMBOLS."
        end

        week = weeks[week] if week.kind_of?(Symbol)
        wday = day_symbols.index(wday) if wday.kind_of?(Symbol)

        # :first, :second, :third, :fourth or :fifth
        if week > 0
          return ((week - 1) * 7) + 1 + ((wday - Date.civil(year, month,(week-1)*7 + 1).wday) % 7)
        end

        days = month_lengths[month-1]

        days = 29 if month == 2 and Date.leap?(year)

        return days - ((Date.civil(year, month, days).wday - wday + 7) % 7) - (7 * (week.abs - 1))
      end

      private

      def weeks
        Holidays::WEEKS
      end

      def day_symbols
        Holidays::DAY_SYMBOLS
      end

      def month_lengths
        Holidays::MONTH_LENGTHS
      end
    end
  end
end
