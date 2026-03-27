# frozen_string_literal: true

module DiscourseWorkflows
  class Form::Resume
    include Service::Base

    params do
      attribute :execution_id, :integer
      attribute :form_data, default: -> { {} }

      validates :execution_id, presence: true
    end

    model :execution
    model :waiting_node
    step :resume_execution

    private

    def fetch_execution(params:)
      execution = DiscourseWorkflows::Execution.find_by(id: params.execution_id, status: :waiting)
      return if execution.nil?
      return if execution.waiting_config&.dig("wait_type") != "form"
      execution
    end

    def fetch_waiting_node(execution:)
      execution.workflow.nodes.find_by(id: execution.waiting_node_id)
    end

    def resume_execution(execution:, waiting_node:, params:, guardian:)
      form_data =
        execution.accumulated_form_data.merge(waiting_node.form_data_from(params.form_data || {}))

      response_items = [
        { "json" => { "form_data" => form_data, "submitted_at" => Time.current.utc.iso8601 } },
      ]
      DiscourseWorkflows::Executor.resume(execution, response_items, user: guardian.user)
    end
  end
end
