# frozen_string_literal: true

module DiscourseWorkflows
  class Form::Submit
    include Service::Base

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

    model :published_trigger
    model :workflow
    model :trigger_node
    policy :authenticated_if_required
    policy :valid_initial_submission_token
    model :submission_token_payload
    model :form_validation, :validate_form
    step :ensure_form_valid
    model :execution, :run_workflow
    model :response_metadata, :build_response_metadata

    private

    def authenticated_if_required(trigger_node:, guardian:)
      return true if NodeData.parameters(trigger_node)["authentication"] != "login_required"
      guardian.authenticated?
    end

    def validate_form(trigger_node:, params:, submission_token_payload:)
      fields =
        Schemas::FormFields.with_keys(
          CollectionParameters.rows(NodeData.parameters(trigger_node), "form_fields"),
        )
      Schemas::FormFields.validate_submission(
        fields,
        params.form_data,
        query_parameters: submission_token_payload["form_query_parameters"],
      )
    end

    def ensure_form_valid(form_validation:)
      unless form_validation.valid?
        fail!(I18n.t("discourse_workflows.errors.invalid_form_submission"))
      end
    end

    def fetch_published_trigger(params:)
      Form::Action::FindPublishedTrigger.call(uuid: params.uuid)
    end

    def fetch_workflow(published_trigger:)
      published_trigger.workflow
    end

    def fetch_trigger_node(published_trigger:)
      published_trigger.trigger_node
    end

    def valid_initial_submission_token(workflow:, trigger_node:, params:)
      params.resume_token.present? &&
        DiscourseWorkflows::FormTriggerToken.valid?(
          params.resume_token,
          workflow_id: workflow.id,
          trigger_node_id: trigger_node["id"],
          uuid: params.uuid,
        )
    end

    def fetch_submission_token_payload(workflow:, trigger_node:, params:)
      DiscourseWorkflows::FormTriggerToken.payload(
        params.resume_token,
        workflow_id: workflow.id,
        trigger_node_id: trigger_node["id"],
        uuid: params.uuid,
      )
    end

    def run_workflow(published_trigger:, form_validation:, submission_token_payload:, guardian:)
      trigger_data =
        DiscourseWorkflows::Forms::Payload.build(
          form_validation.data,
          query_parameters: submission_token_payload["form_query_parameters"],
        )

      DiscourseWorkflows::TriggerDispatcher.execute(
        published_trigger,
        trigger_data: trigger_data,
        user: guardian.user,
      )
    end

    def build_response_metadata(workflow:, trigger_node:)
      {
        has_downstream_form:
          workflow.node_has_reachable_downstream_of_type?(
            trigger_node["id"],
            "action:form",
            published: true,
          ),
        response_mode: NodeData.parameters(trigger_node)["response_mode"] || "on_received",
      }
    end
  end
end
