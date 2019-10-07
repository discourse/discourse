# frozen_string_literal: true

module Jobs
  class DiscourseAutomationProcessPlan < ::Jobs::Base
    def execute(args)
      plan = DiscourseAutomation::Plan.find(args[:plan_id])
      plannable = plan.plannable

      plannable[:plan].call(
        plan.options,
        args[:trigger][:args]
      )
    end
  end
end
