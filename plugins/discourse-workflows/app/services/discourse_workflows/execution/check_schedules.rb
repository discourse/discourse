# frozen_string_literal: true

module DiscourseWorkflows
  class Execution::CheckSchedules
    include Service::Base

    policy :workflows_enabled, class_name: DiscourseWorkflows::Policy::WorkflowsEnabled
    step :tick_triggers

    private

    def tick_triggers
      TriggerRuntime.tick!(now: Time.current.utc)
    end
  end
end
