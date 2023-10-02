# frozen_string_literal: true

module Jobs
  class DiscourseAutomationTrigger < ::Jobs::Base
    def execute(args)
      automation = DiscourseAutomation::Automation.find_by(id: args[:automation_id], enabled: true)

      return if !automation

      context = DiscourseAutomation::Automation.deserialize_context(args[:context])

      automation.running_in_background!
      automation.trigger!(context)
    end
  end
end
