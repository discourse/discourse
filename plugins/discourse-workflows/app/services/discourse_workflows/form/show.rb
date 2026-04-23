# frozen_string_literal: true

module DiscourseWorkflows
  class Form::Show
    include Service::Base

    params do
      attribute :uuid, :string
      attribute :resume_token, :string

      validates :uuid, presence: true
    end

    model :waiting_execution, optional: true

    only_if(:resuming?) do
      model :workflow, :fetch_workflow_from_execution
      model :form_node, :fetch_form_node_from_execution
      model :form_data, :build_form_data_from_execution
    end

    only_if(:initial_request?) do
      model :workflow, :fetch_workflow_by_uuid
      model :form_node, :fetch_form_node_from_workflow
      policy :authenticated_if_required
      model :form_data, :build_form_data_from_config
    end

    private

    def resuming?(waiting_execution:)
      waiting_execution.present?
    end

    def initial_request?(waiting_execution:)
      waiting_execution.blank?
    end

    def authenticated_if_required(form_node:, guardian:)
      return true if form_node.dig("configuration", "authentication") != "login_required"
      guardian.authenticated?
    end

    def fetch_waiting_execution(params:)
      return unless params.resume_token

      execution = DiscourseWorkflows::Execution.by_resume_token(params.resume_token).first
      return unless execution

      node = execution.workflow.find_node(execution.waiting_node_id)
      return unless node&.dig("type") == "action:form"

      execution
    end

    def fetch_workflow_from_execution(waiting_execution:)
      waiting_execution.workflow
    end

    def fetch_form_node_from_execution(waiting_execution:)
      waiting_execution.workflow.find_node(waiting_execution.waiting_node_id)
    end

    def fetch_workflow_by_uuid(params:)
      DiscourseWorkflows::WorkflowDependency
        .enabled_workflows_with_node_type("trigger:form")
        .each do |workflow, node|
          config = node["configuration"] || {}
          return workflow if config["uuid"] == params.uuid
        end
      nil
    end

    def fetch_form_node_from_workflow(params:, workflow:)
      workflow
        .nodes_of_type("trigger:form")
        .find do |node|
          config = node["configuration"] || {}
          config["uuid"] == params.uuid
        end
    end

    def build_form_data_from_execution(
      waiting_execution:,
      workflow:,
      form_node:,
      params:,
      guardian:
    )
      resume_token = waiting_execution.resume_token
      context_data = waiting_execution.execution_data&.context_data || {}

      exec_context =
        context_data.merge(
          "__execution" => {
            "id" => waiting_execution.id,
            "workflow_id" => workflow.id,
            "workflow_name" => workflow.name,
            "resume_url" =>
              "#{Discourse.base_url}/workflows/webhooks/#{waiting_execution.id}?token=#{resume_token}",
          },
        )

      config = form_node["configuration"] || {}

      {
        uuid: params.uuid,
        form_title:
          ExpressionResolver.resolve(
            config["form_title"],
            context: exec_context,
            user: guardian.user,
          ),
        form_description:
          ExpressionResolver.resolve(
            config["form_description"],
            context: exec_context,
            user: guardian.user,
          ),
        form_fields: Workflow.resolve_field_keys(config["form_fields"] || []),
        response_mode: "on_received",
        has_downstream_form:
          workflow.node_has_reachable_downstream_of_type?(form_node["id"], "action:form"),
        resume_token: resume_token,
      }
    end

    def build_form_data_from_config(workflow:, form_node:, params:, guardian:)
      resume_token =
        DiscourseWorkflows::FormTriggerToken.generate(
          workflow_id: workflow.id,
          trigger_node_id: form_node["id"],
          uuid: params.uuid,
        )

      exec_context = {
        "__execution" => {
          "workflow_id" => workflow.id,
          "workflow_name" => workflow.name,
          "resume_url" => "",
        },
      }

      config =
        ExpressionResolver.resolve_hash(
          (form_node["configuration"] || {}).deep_stringify_keys,
          context: exec_context,
          user: guardian.user,
        )

      {
        uuid: params.uuid,
        form_title: config["form_title"],
        form_description: config["form_description"],
        form_fields: Workflow.resolve_field_keys(config["form_fields"] || []),
        response_mode: config["response_mode"] || "on_received",
        has_downstream_form:
          workflow.node_has_reachable_downstream_of_type?(form_node["id"], "action:form"),
        resume_token: resume_token,
      }
    end
  end
end
