# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::PreviewsController do
  fab!(:admin)
  fab!(:workflow) do
    graph =
      build_workflow_graph do |builder|
        builder.node "trigger-1", "trigger:manual", name: "Run manually"
        builder.node "trigger-2", "trigger:topic_created", name: "Topic created"
      end
    Fabricate(:discourse_workflows_workflow, created_by: admin, **graph)
  end

  let(:path) { "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/previews.json" }

  before do
    SiteSetting.discourse_workflows_tests_enabled = true
    sign_in(admin)
  end

  it "returns 404 when the feature is disabled" do
    SiteSetting.discourse_workflows_tests_enabled = false

    post path, params: { trigger_node_id: "trigger-1" }

    expect(response).to have_http_status(:not_found)
  end

  it "enqueues a preview simulation" do
    post path, params: { trigger_node_id: "trigger-1" }

    expect(response).to have_http_status(:created)
    execution = DiscourseWorkflows::Execution.find(response.parsed_body["execution"]["id"])
    expect(execution).to have_attributes(execution_mode: "simulation", workflow_test_id: nil)
    expect(Jobs::DiscourseWorkflows::RunSimulation.jobs.size).to eq(1)
  end

  it "explains when the trigger has no sample input" do
    post path, params: { trigger_node_id: "trigger-2" }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body["errors"].first).to include("no sample input")
  end
end
