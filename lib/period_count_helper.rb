# frozen_string_literal: true

module PeriodCountHelper
  def period_counts(scope, column, count: true, &aggregate)
    aggregate ||= ->(relation) { relation.count }
    col = scope.arel_table[column]
    result = {
      last_day: aggregate.call(scope.where(col.gt(1.day.ago))),
      "7_days": aggregate.call(scope.where(col.gt(7.days.ago))),
      "30_days": aggregate.call(scope.where(col.gt(30.days.ago))),
      previous_30_days: aggregate.call(scope.where(col.between(60.days.ago..30.days.ago))),
    }
    result[:count] = aggregate.call(scope) if count
    result
  end
end
