module Jobs
  class DiscourseAutomationEveryMonthTrigger < DiscourseAutomationRecurringTrigger
    every 1.month

    def type
      :every_month
    end
  end
end
