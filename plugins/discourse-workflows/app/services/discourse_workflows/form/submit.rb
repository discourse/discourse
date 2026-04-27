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
    policy :authenticated_if_required
    step :validate_initial_submission_token
    step :validate_form_submission
    model :execution, :run_workflow
    model :response_metadata, :build_response_metadata

    private

    def authenticated_if_required(trigger_node:, guardian:)
      return true if trigger_node.dig("configuration", "authentication") != "login_required"
      guardian.authenticated?
    end

    def validate_form_submission(trigger_node:, params:)
      result = FormSchema.validate(trigger_node, params.form_data)
      if !result.valid?
        context[:form_errors] = result.errors.map(&:to_h)
        fail!(I18n.t("discourse_workflows.errors.invalid_form_submission"))
      end
      context[:coerced_form_data] = result.data
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

    def validate_initial_submission_token(workflow:, trigger_node:, params:)
      if params.resume_token.present? &&
           DiscourseWorkflows::FormTriggerToken.valid?(
             params.resume_token,
             workflow_id: workflow.id,
             trigger_node_id: trigger_node["id"],
             uuid: params.uuid,
           )
        return
      end

      fail!(I18n.t("discourse_workflows.errors.invalid_form_token"))
    end

    def run_workflow(workflow:, trigger_node:, coerced_form_data:, guardian:)
      coerced_form_data.transform_values! do |v|
        v.is_a?(String) ? v.truncate(MAX_FIELD_VALUE_LENGTH) : v
      end
      trigger_data = {
        "form_data" => coerced_form_data,
        "submitted_at" => Time.current.utc.iso8601,
      }

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
