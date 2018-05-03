module DateGroupable extend ActiveSupport::Concern
  class_methods do
    def group_by_day(column)
      group_by_unit(:day, column)
    end

    def group_by_week(column)
      group_by_unit(:week, column)
    end

    def group_by_month(column)
      group_by_unit(:month, column)
    end

    def group_by_quarter(column)
      group_by_unit(:quarter, column)
    end

    def group_by_year(column)
      group_by_unit(:year, column)
    end

    def group_by_unit(aggregation_unit, column)
      group("date_trunc('#{aggregation_unit}', #{column})::DATE")
        .order("date_trunc('#{aggregation_unit}', #{column})::DATE")
    end

    def aggregation_unit_for_period(start_date, end_date)
      days = (start_date.to_date..end_date.to_date).count

      case
      when days <= 40
        return :day
      when days <= 210 # 30 weeks
        return :week
      when days <= 550 # ~18 months
        return :month
      when days <= 1461 # ~4 years
        return :quarter
      else
        return :year
      end
    end

    def smart_group_by_date(column, start_date, end_date)
      aggregation_unit = aggregation_unit_for_period(start_date, end_date)

      where("#{column} BETWEEN ? AND ?", start_date, end_date)
        .group_by_unit(aggregation_unit, column)
    end
  end
end
