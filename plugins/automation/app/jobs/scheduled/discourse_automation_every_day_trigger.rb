module Jobs
  class DiscourseAutomationEveryDayTrigger < DiscourseAutomationRecurringTrigger
    every 1.day

    def type
      :every_day
    end
  end
end
