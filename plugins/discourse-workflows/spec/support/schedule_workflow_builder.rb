# frozen_string_literal: true

module DiscourseWorkflows
  class ScheduleWorkflowBuilder
    def self.configuration(*rules)
      { "rule" => { "interval" => rules } }
    end

    def initialize(user:)
      @user = user
    end

    def create(configuration:, settings: {})
      graph = WorkflowGraphBuilder.new.node("trigger-1", "trigger:schedule", configuration:).to_h

      Fabricate(
        :discourse_workflows_workflow,
        published: true,
        created_by: @user,
        settings:,
        **graph,
      )
    end
  end
end
