# frozen_string_literal: true

module DiscourseWorkflows
  class Form::Resume
    include Service::Base

    policy :workflows_enabled, class_name: DiscourseWorkflows::Policy::WorkflowsEnabled

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
    step :validate_required_form_fields
    step :resume_execution

    private

    def validate_required_form_fields(waiting_node:, params:)
      missing = Workflow.missing_required_form_fields(waiting_node, params.form_data)
      if missing.present?
        context[:missing_fields] = missing
        fail!(I18n.t("discourse_workflows.errors.missing_required_fields"))
      end
    end

    def fetch_execution(params:)
      DiscourseWorkflows::Executor::WaitHandlers::Form
        .find_waiting_execution_by_resume_token(params.resume_token)
        .lock("FOR UPDATE SKIP LOCKED")
        .first
    end

    def fetch_waiting_node(execution:)
      execution.workflow.find_node(execution.waiting_node_id)
    end

    def resume_execution(execution:, waiting_node:, params:, guardian:)
      form_data =
        execution.accumulated_form_data.merge(
          DiscourseWorkflows::Workflow.form_data_from(waiting_node, params.form_data),
        )

      response_items = [
        { "json" => { "form_data" => form_data, "submitted_at" => Time.current.utc.iso8601 } },
      ]
      DiscourseWorkflows::Executor.resume(execution, response_items, user: guardian.user)
    end
  end
end
