module Jobs
  class DiscourseAutomationEveryYearTrigger < DiscourseAutomationRecurringTrigger
    every 1.year

    def type
      :every_year
    end
  end
end
