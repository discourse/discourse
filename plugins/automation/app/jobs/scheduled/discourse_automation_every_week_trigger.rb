module Jobs
  class DiscourseAutomationEveryWeekTrigger < DiscourseAutomationRecurringTrigger
    every 1.week

    def type
      :every_week
    end
  end
end
