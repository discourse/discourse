# frozen_string_literal: true

module DiscourseWorkflows
  class Form::Resume
    include Service::Base

    params do
      attribute :resume_token, :string
      attribute :form_data, default: -> { {} }

      validates :resume_token, presence: true
      validate :form_data_must_be_hash

      def form_data_must_be_hash
        errors.add(:form_data, :invalid) unless form_data.is_a?(Hash)
      end
    end

    model :execution
    model :waiting_node
    step :resume_execution

    private

    def fetch_execution(params:)
      DiscourseWorkflows::Execution
        .where(status: :waiting)
        .where("waiting_config->>'resume_token' = ?", params.resume_token)
        .where("waiting_config->>'wait_type' = ?", "form")
        .first
    end

    def fetch_waiting_node(execution:)
      execution.workflow.nodes.find_by(id: execution.waiting_node_id)
    end

    def resume_execution(execution:, waiting_node:, params:, guardian:)
      form_data =
        execution.accumulated_form_data.merge(waiting_node.form_data_from(params.form_data))

      response_items = [
        { "json" => { "form_data" => form_data, "submitted_at" => Time.current.utc.iso8601 } },
      ]
      DiscourseWorkflows::Executor.resume(execution, response_items, user: guardian.user)
    end
  end
end
