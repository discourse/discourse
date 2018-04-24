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
      group("date_trunc('#{aggregation_unit}', #{column})")
        .order("date_trunc('#{aggregation_unit}', #{column})")
    end

    def smart_group_by_date(column, start_date, end_date)
      days = (start_date.to_date..end_date.to_date).count

      case
      when days <= 40
        aggregation_unit = :day
      when days <= 210  # 30 weeks
        aggregation_unit = :week
      when days <= 550  # ~18 months
        aggregation_unit = :month
      when days <= 1461  # ~4 years
        aggregation_unit = :quarter
      else
        aggregation_unit = :year
      end

      where("#{column} BETWEEN ? AND ?", start_date, end_date)
        .group_by_unit(aggregation_unit, column)
    end
  end
end
