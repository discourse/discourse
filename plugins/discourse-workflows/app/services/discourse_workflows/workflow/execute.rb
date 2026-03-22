# frozen_string_literal: true

module DiscourseWorkflows
  class Workflow::Execute
    include Service::Base

    params do
      attribute :trigger_node_id, :integer
      attribute :trigger_data
    end

    model :trigger_node
    model :workflow
    step :execute_workflow

    private

    def fetch_trigger_node(params:)
      DiscourseWorkflows::Node.find_by(id: params.trigger_node_id)
    end

    def fetch_workflow(trigger_node:)
      trigger_node.workflow
    end

    def execute_workflow(trigger_node:, params:)
      trigger_output = params.trigger_data || {}
      DiscourseWorkflows::Executor.new(trigger_node, trigger_output).run
    end
  end
end
