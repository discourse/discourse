# frozen_string_literal: true

module DiscourseWorkflows
  class Form::Show
    include Service::Base

    params do
      attribute :uuid, :string
      attribute :execution_id, :integer

      validates :uuid, presence: true
    end

    model :waiting_execution, optional: true
    model :form_node

    only_if(:resuming_execution) { step :build_waiting_form_data }

    only_if(:initial_form_request) { step :build_trigger_form_data }

    private

    def resuming_execution(waiting_execution:)
      waiting_execution.present?
    end

    def initial_form_request(waiting_execution:)
      waiting_execution.nil?
    end

    def fetch_waiting_execution(params:)
      return unless params.execution_id
      execution = DiscourseWorkflows::Execution.find_by(id: params.execution_id, status: :waiting)
      return if execution.nil?
      return if execution.waiting_config&.dig("wait_type") != "form"
      execution
    end

    def fetch_form_node(params:, waiting_execution:)
      if waiting_execution
        waiting_execution.workflow.nodes.find_by(id: waiting_execution.waiting_node_id)
      else
        DiscourseWorkflows::Node.enabled_of_type("trigger:form").find_by(
          "configuration->>'uuid' = ?",
          params.uuid,
        )
      end
    end

    def build_waiting_form_data(waiting_execution:, form_node:, params:)
      wc = waiting_execution.waiting_config
      context[:form_data] = {
        uuid: params.uuid,
        form_title: wc["form_title"],
        form_description: wc["form_description"],
        form_fields: wc["form_fields"] || [],
        response_mode: "on_received",
        has_downstream_form: form_node.downstream_form?,
      }
    end

    def build_trigger_form_data(form_node:, params:)
      resolver = ExpressionResolver.new({})
      config = resolver.resolve_hash(form_node.configuration.deep_stringify_keys)
      context[:form_data] = {
        uuid: params.uuid,
        form_title: config["form_title"],
        form_description: config["form_description"],
        form_fields: config["form_fields"] || [],
        response_mode: config["response_mode"] || "on_received",
        has_downstream_form: form_node.downstream_form?,
      }
    end
  end
end
