# frozen_string_literal: true

module Jobs
  class DiscourseAutomationProcessWorkflow < ::Jobs::Base
    def execute(args)
      should_trigger = true

      workflow = DiscourseAutomation::Workflow
        .includes(:plans, :trigger)
        .find(args[:workflow_id])

      if !workflow.trigger
        return
      end

      triggerable = DiscourseAutomation::Triggerable[workflow.trigger.identifier]
      if triggerable[:trigger]
        options = OpenStruct.new(workflow.trigger.options)
      else
        return
      end

      return if !should_trigger

      workflow.plans.find_each do |plan|
        Jobs.enqueue_at(
          plan.delay.minutes.from_now,
          :discourse_automation_process_plan,
          {
            trigger: {
              args: args,
              options: options
            },
            placeholders: triggerable[:placeholders],
            plan_id: plan.id
          }
        )
      end
    end
  end
end
