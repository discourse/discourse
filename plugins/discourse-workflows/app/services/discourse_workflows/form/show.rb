# frozen_string_literal: true

module DiscourseWorkflows
  class Form::Show
    include Service::Base

    params do
      attribute :uuid, :string
      attribute :form_query_parameters, default: -> { {} }

      validates :uuid, presence: true
      validate :form_query_parameters_must_be_hash

      def form_query_parameters_must_be_hash
        errors.add(:form_query_parameters, :invalid) unless form_query_parameters.is_a?(Hash)
      end
    end

    model :published_trigger, :fetch_published_trigger_by_uuid
    model :workflow, :fetch_workflow_from_published_trigger
    model :workflow_version, :fetch_workflow_version_from_published_trigger
    model :form_node, :fetch_form_node_from_published_trigger
    policy :authenticated_if_required
    model :form_data, :build_form_data_from_config

    private

    def authenticated_if_required(form_node:, guardian:)
      return true if NodeData.parameters(form_node)["authentication"] != "login_required"
      guardian.authenticated?
    end

    def fetch_published_trigger_by_uuid(params:)
      Form::Action::FindPublishedTrigger.call(uuid: params.uuid)
    end

    def fetch_workflow_from_published_trigger(published_trigger:)
      published_trigger.workflow
    end

    def fetch_workflow_version_from_published_trigger(published_trigger:)
      published_trigger.workflow_version
    end

    def fetch_form_node_from_published_trigger(published_trigger:)
      published_trigger.trigger_node
    end

    def build_form_data_from_config(workflow:, workflow_version:, form_node:, params:, guardian:)
      resume_token =
        DiscourseWorkflows::FormTriggerToken.generate(
          workflow_id: workflow.id,
          trigger_node_id: form_node["id"],
          uuid: params.uuid,
          form_query_parameters: params.form_query_parameters,
        )

      exec_context = {
        "__execution" => {
          "workflow_id" => workflow.id,
          "workflow_name" => workflow_version.name,
          "resume_url" => "",
          "resumeFormUrl" => "",
        },
      }

      config =
        ExpressionResolver.resolve_hash(
          NodeData.parameters(form_node).deep_stringify_keys,
          context: exec_context,
          user: guardian.user,
        )

      fields =
        Schemas::FormFields.apply_query_defaults(
          Schemas::FormFields.with_keys(CollectionParameters.rows(config, "form_fields")),
          params.form_query_parameters,
        )

      DiscourseWorkflows::Forms::ViewModel.build(
        fields: fields,
        form_title: config["form_title"],
        form_description: config["form_description"],
        response_mode: config["response_mode"] || "on_received",
        has_downstream_form:
          workflow.node_has_reachable_downstream_of_type?(
            form_node["id"],
            "action:form",
            published: true,
          ),
        form_submit_url: "/workflows/form/#{params.uuid}.json",
        resume_token: resume_token,
      )
    end
  end
end
