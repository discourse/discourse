module Jobs
  class DiscourseAutomationEveryHourTrigger < DiscourseAutomationRecurringTrigger
    every 1.hour

    def type
      :every_hour
    end
  end
end
