# frozen_string_literal: true

module DiscourseWorkflows
  class FormTestSession::Submit
    include Service::Base

    params do
      attribute :token, :string
      attribute :form_data, default: -> { {} }

      validates :token, presence: true
      validate :form_data_must_be_hash

      def form_data_must_be_hash
        errors.add(:form_data, :invalid) unless form_data.is_a?(Hash)
      end
    end

    model :form_test_session
    model :workflow
    policy :owns_form_test_session
    model :form_node, :fetch_form_node_from_session
    model :form_validation, :validate_form
    step :ensure_form_valid
    model :execution, :run_workflow
    model :response_metadata, :build_response_metadata

    private

    def fetch_form_test_session(params:)
      FormTestSession.find(params.token)
    end

    def fetch_workflow(form_test_session:)
      Workflow.find_by(id: form_test_session.workflow_id)
    end

    def owns_form_test_session(form_test_session:, guardian:)
      form_test_session.owned_by?(guardian.user)
    end

    def fetch_form_node_from_session(form_test_session:)
      form_test_session.trigger_node
    end

    def validate_form(form_node:, params:)
      fields =
        Schemas::FormFields.with_keys(
          CollectionParameters.rows(NodeData.parameters(form_node), "form_fields"),
        )
      Schemas::FormFields.validate_submission(fields, params.form_data)
    end

    def ensure_form_valid(form_validation:)
      unless form_validation.valid?
        fail!(I18n.t("discourse_workflows.errors.invalid_form_submission"))
      end
    end

    def run_workflow(form_test_session:, workflow:, form_validation:, guardian:)
      trigger_data =
        Forms::Payload.build(form_validation.data, form_mode: "test", query_parameters: nil)
      options =
        Executor::ExecutionOptions.new(
          user: guardian.user,
          execution_mode: :manual,
          draft_execution: true,
          workflow_snapshot: form_test_session.workflow_snapshot,
        )

      Executor.new(workflow, form_test_session.trigger_node_id, trigger_data, options).run
    end

    def build_response_metadata(form_test_session:, form_node:)
      {
        has_downstream_form:
          form_test_session.workflow_snapshot.node_has_reachable_downstream_of_type?(
            form_node.id,
            "action:form",
          ),
        response_mode: NodeData.parameters(form_node)["response_mode"] || "on_received",
      }
    end
  end
end
