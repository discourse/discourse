# frozen_string_literal: true

module DiscourseWorkflows
  class Form::Submit
    include Service::Base

    MAX_FIELD_VALUE_LENGTH = 10_000

    params do
      attribute :uuid, :string
      attribute :resume_token, :string
      attribute :form_data, default: -> { {} }

      validates :uuid, presence: true
      validate :form_data_must_be_hash

      def form_data_must_be_hash
        errors.add(:form_data, :invalid) unless form_data.is_a?(Hash)
      end
    end

    model :workflow
    model :trigger_node
    step :validate_required_form_fields
    model :execution, :run_workflow
    model :response_metadata, :build_response_metadata

    private

    def validate_required_form_fields(trigger_node:, params:)
      missing = Workflow.missing_required_form_fields(trigger_node, params.form_data)
      if missing.present?
        context[:missing_fields] = missing
        fail!(I18n.t("discourse_workflows.errors.missing_required_fields"))
      end
    end

    def fetch_workflow(params:)
      DiscourseWorkflows::WorkflowDependency
        .enabled_workflows_with_node_type("trigger:form")
        .each do |workflow, node|
          config = node["configuration"] || {}
          return workflow if config["uuid"] == params.uuid
        end
      nil
    end

    def fetch_trigger_node(workflow:, params:)
      workflow
        .nodes_of_type("trigger:form")
        .find { |node| node.dig("configuration", "uuid") == params.uuid }
    end

    def run_workflow(workflow:, trigger_node:, params:, guardian:)
      form_data = DiscourseWorkflows::Workflow.form_data_from(trigger_node, params.form_data)
      form_data.transform_values! { |v| v.is_a?(String) ? v.truncate(MAX_FIELD_VALUE_LENGTH) : v }
      trigger_data = { "form_data" => form_data, "submitted_at" => Time.current.utc.iso8601 }
      response_items = [{ "json" => trigger_data }]

      if params.resume_token.present?
        execution =
          DiscourseWorkflows::Execution
            .where(status: :waiting, workflow: workflow)
            .where("waiting_config->>'resume_token' = ?", params.resume_token)
            .where("waiting_config->>'wait_type' = ?", "form_trigger")
            .first

        if execution
          execution.update!(trigger_data: trigger_data)
          return DiscourseWorkflows::Executor.resume(execution, response_items, user: guardian.user)
        end
      end

      options = DiscourseWorkflows::Executor::ExecutionOptions.new(user: guardian.user)
      DiscourseWorkflows::Executor.new(workflow, trigger_node["id"], trigger_data, options).run
    end

    def build_response_metadata(workflow:, trigger_node:)
      {
        has_downstream_form:
          workflow.node_has_reachable_downstream_of_type?(trigger_node["id"], "action:form"),
        response_mode: trigger_node.dig("configuration", "response_mode") || "on_received",
      }
    end
  end
end
