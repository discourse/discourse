module Holidays
  module DateCalculator
    module Easter
      class Gregorian
        def calculate_easter_for(year)
          y = year
          a = y % 19
          b = y / 100
          c = y % 100
          d = b / 4
          e = b % 4
          f = (b + 8) / 25
          g = (b - f + 1) / 3
          h = (19 * a + b - d - g + 15) % 30
          i = c / 4
          k = c % 4
          l = (32 + 2 * e + 2 * i - h - k) % 7
          m = (a + 11 * h + 22 * l) / 451

          month = (h + l - 7 * m + 114) / 31
          day = ((h + l - 7 * m + 114) % 31) + 1

          Date.civil(year, month, day)
        end

        def calculate_orthodox_easter_for(year)
          j_date = Julian.new.calculate_orthodox_easter_for(year)

          case
          # up until 1582, julian and gregorian easter dates were identical
          when year <= 1582
            offset = 0
          # between the years 1583 and 1699 10 days are added to the julian day count
          when (year >= 1583 and year <= 1699)
            offset = 10
          # after 1700, 1 day is added for each century, except if the century year is exactly divisible by 400 (in which case no days are added).
          # Safe until 4100 AD, when one leap day will be removed.
          when year >= 1700
            offset = (year - 1700).divmod(100)[0] + ((year - year.divmod(100)[1]).divmod(400)[1] == 0 ? 0 : 1) - (year - year.divmod(100)[1] - 1700).divmod(400)[0] + 10
          end


          Date.jd(j_date.jd + offset)
        end
      end

      class Julian
        # Copied from https://github.com/Loyolny/when_easter
        # Graciously allowed by Michał Nierebiński (https://github.com/Loyolny)
        def calculate_easter_for(year)
          g = year % 19 + 1
          s = (year - 1600) / 100 - (year - 1600) / 400
          l = (((year - 1400) / 100) * 8) / 25

          p_2 = (3 - 11 * g + s - l) % 30
          if p_2 == 29 || (p_2 == 28 && g > 11)
            p = p_2 - 1
          else
            p = p_2
          end

          d= (year + year / 4 - year / 100 + year / 400) % 7
          d_2 = (8 - d) % 7

          p_3 = (80 + p) % 7
          x_2 = d_2 - p_3

          x = (x_2 - 1) % 7 + 1
          e = p+x

          if e < 11
            Date.civil(year,3,e + 21)
          else
            Date.civil(year,4,e - 10)
          end
        end

        def calculate_orthodox_easter_for(year)
          y = year
          g = y % 19
          i = (19 * g + 15) % 30
          j = (year + year/4 + i) % 7
          j_month = 3 + (i - j + 40) / 44
          j_day = i - j + 28 - 31 * (j_month / 4)

          Date.civil(year, j_month, j_day)
        end
      end
    end
  end
end
