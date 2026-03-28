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
    model :form_node
    model :form_data, :build_form_data

    private

    def fetch_waiting_execution(params:)
      return unless params.resume_token
      DiscourseWorkflows::Execution
        .where(status: :waiting)
        .where("waiting_config->>'resume_token' = ?", params.resume_token)
        .where("waiting_config->>'wait_type' = ?", "form")
        .first
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

    def build_form_data(waiting_execution:, form_node:, params:, guardian:)
      resolver = ExpressionResolver.new({}, user: guardian.user)

      if waiting_execution
        wc = waiting_execution.waiting_config
        {
          uuid: params.uuid,
          form_title: resolver.resolve(wc["form_title"]),
          form_description: resolver.resolve(wc["form_description"]),
          form_fields: wc["form_fields"] || [],
          response_mode: "on_received",
          has_downstream_form: form_node.downstream_form?,
        }
      else
        config = resolver.resolve_hash(form_node.configuration.deep_stringify_keys)
        {
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
end
