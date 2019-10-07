module Jobs
  class DiscourseAutomationEveryTenMinutesTrigger < DiscourseAutomationRecurringTrigger
    every 10.minutes

    def type
      :every_ten_minutes
    end
  end
end
