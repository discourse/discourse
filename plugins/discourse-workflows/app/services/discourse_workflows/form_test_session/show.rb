# frozen_string_literal: true

module DiscourseWorkflows
  class FormTestSession::Show
    include Service::Base

    params do
      attribute :token, :string

      validates :token, presence: true
    end

    model :form_test_session
    model :workflow
    policy :owns_form_test_session
    model :form_node, :fetch_form_node_from_session
    model :form_data, :build_form_data_from_config

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

    def build_form_data_from_config(form_test_session:, workflow:, form_node:, guardian:, params:)
      config =
        ExpressionResolver.resolve_hash(
          NodeData.parameters(form_node).deep_stringify_keys,
          context: {
            "__execution" => {
              "workflow_id" => workflow.id,
              "workflow_name" => form_test_session.workflow_snapshot.workflow_name,
              "resume_url" => "",
              "resumeFormUrl" => "",
            },
          },
          user: guardian.user,
        )

      fields = Schemas::FormFields.with_keys(CollectionParameters.rows(config, "form_fields"))

      Forms::ViewModel.build(
        fields: fields,
        form_title: config["form_title"],
        form_description: config["form_description"],
        response_mode: config["response_mode"] || "on_received",
        has_downstream_form:
          form_test_session.workflow_snapshot.node_has_reachable_downstream_of_type?(
            form_node.id,
            "action:form",
          ),
        form_submit_url: "/workflows/form-test/#{params.token}.json",
        form_mode: "test",
      )
    end
  end
end
