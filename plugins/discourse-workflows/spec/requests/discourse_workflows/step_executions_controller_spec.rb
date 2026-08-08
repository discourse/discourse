# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::StepExecutionsController do
  fab!(:admin)
  fab!(:workflow) do
    graph =
      build_workflow_graph do |g|
        g.node "trigger-1", "trigger:post_created"
        g.node "set-1",
               "action:set_fields",
               configuration: {
                 "mode" => "raw",
                 "include_other_fields" => true,
                 "json_output" => '{"a": 1}',
               }
        g.chain "trigger-1", "set-1"
      end
    Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
  end

  before { sign_in(admin) }

  describe "POST /admin/plugins/discourse-workflows/step-executions" do
    it "returns a pending step execution" do
      workflow.update_node_pin_data!("Trigger-1", [{ "json" => { "post" => { "id" => 1 } } }])

      post "/admin/plugins/discourse-workflows/step-executions.json",
           params: {
             workflow_id: workflow.id,
             node_id: "set-1",
           }

      expect(response).to have_http_status(:created)
      execution = DiscourseWorkflows::Execution.find(response.parsed_body.dig("execution", "id"))
      expect(response.parsed_body["execution"]).to include(
        "id" => execution.id,
        "workflow_id" => workflow.id,
      )
      expect(execution.status).to eq("pending")
      expect(execution.trigger_node_id).to eq("set-1")

      job_args = Jobs::DiscourseWorkflows::ExecuteManualWorkflow.jobs.last["args"].first
      expect(job_args).to include(
        "execution_id" => execution.id,
        "user_id" => admin.id,
        "step_node_id" => "set-1",
      )
    end

    it "returns 422 with an error message when the node has no input data" do
      post "/admin/plugins/discourse-workflows/step-executions.json",
           params: {
             workflow_id: workflow.id,
             node_id: "set-1",
           }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["errors"]).to include(
        I18n.t("discourse_workflows.errors.step_execution.missing_input_data"),
      )
    end

    it "returns 404 for non-admin users" do
      sign_in(Fabricate(:user))

      post "/admin/plugins/discourse-workflows/step-executions.json",
           params: {
             workflow_id: workflow.id,
             node_id: "set-1",
           }

      expect(response).to have_http_status(:not_found)
    end
  end
end
