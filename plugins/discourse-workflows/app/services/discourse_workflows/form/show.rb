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
      model :form_data, :build_form_data_from_config
    end

    private

    def resuming?(waiting_execution:)
      waiting_execution.present?
    end

    def initial_request?(waiting_execution:)
      waiting_execution.blank?
    end

    def fetch_waiting_execution(params:)
      return unless params.resume_token

      DiscourseWorkflows::Executor::WaitHandlers::Form.find_waiting_execution_by_resume_token(
        params.resume_token,
      ).first
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
      wc = waiting_execution.waiting_config

      {
        uuid: params.uuid,
        form_title: ExpressionResolver.resolve(wc["form_title"], user: guardian.user),
        form_description: ExpressionResolver.resolve(wc["form_description"], user: guardian.user),
        form_fields: Workflow.resolve_field_keys(wc["form_fields"] || []),
        response_mode: "on_received",
        has_downstream_form:
          workflow.node_has_reachable_downstream_of_type?(form_node["id"], "action:form"),
      }
    end

    def build_form_data_from_config(workflow:, form_node:, params:, guardian:)
      config =
        ExpressionResolver.resolve_hash(
          (form_node["configuration"] || {}).deep_stringify_keys,
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
      }
    end
  end
end
