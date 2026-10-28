# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::WorkflowTestsController do
  fab!(:admin)
  fab!(:workflow) do
    graph =
      build_workflow_graph do |builder|
        builder.node "trigger-1", "trigger:manual", name: "Run manually"
        builder.node "http-1",
                     "action:http_request",
                     name: "Call API",
                     configuration: {
                       "url" => "https://example.com",
                     }
        builder.chain "trigger-1", "http-1"
      end
    Fabricate(:discourse_workflows_workflow, created_by: admin, **graph)
  end
  fab!(:workflow_test) { Fabricate(:discourse_workflows_workflow_test, workflow:) }

  let(:base_path) { "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/tests" }

  before do
    SiteSetting.discourse_workflows_tests_enabled = true
    sign_in(admin)
  end

  context "when the feature is disabled" do
    before { SiteSetting.discourse_workflows_tests_enabled = false }

    it "returns 404 for every action" do
      get "#{base_path}.json"
      expect(response).to have_http_status(:not_found)

      post "#{base_path}/run.json"
      expect(response).to have_http_status(:not_found)
    end
  end

  context "when not an admin" do
    fab!(:user)

    before { sign_in(user) }

    it "returns 404" do
      get "#{base_path}.json"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET index" do
    it "lists the workflow's tests with their state" do
      get "#{base_path}.json"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["tests"].first).to include(
        "id" => workflow_test.id,
        "name" => workflow_test.name,
        "state" => "not_run",
        "steps_needing_response" => ["Call API"],
        "checks_count" => 1,
      )
    end
  end

  describe "GET show" do
    it "returns the test with its checks and replay steps" do
      get "#{base_path}/#{workflow_test.id}.json"

      expect(response).to have_http_status(:ok)
      test = response.parsed_body["test"]
      expect(test["checks"].first).to include("effect" => "finishes")
      expect(test["replay_steps"].first).to include("name" => "Call API", "kind" => "external")
      expect(test["latest_result"]).to be_nil
    end
  end

  describe "POST create" do
    fab!(:execution) do
      execution =
        Fabricate(
          :discourse_workflows_completed_execution,
          workflow:,
          trigger_node_id: "trigger-1",
          trigger_data: {
            "hello" => "world",
          },
          execution_mode: :manual,
        )
      Fabricate(
        :discourse_workflows_execution_data,
        execution:,
        workflow_data:
          DiscourseWorkflows::WorkflowSnapshot.from_workflow(workflow, published: false).to_h,
      )
      execution
    end

    it "creates a test from a run" do
      post "#{base_path}.json", params: { execution_id: execution.id, name: "Welcome" }

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["test"]).to include(
        "name" => "Welcome",
        "trigger_data" => {
          "hello" => "world",
        },
      )
    end

    it "returns 422 with a reason when the run cannot be saved" do
      execution.update!(status: :rate_limited)

      post "#{base_path}.json", params: { execution_id: execution.id }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["errors"].first).to include("can't be saved as a test")
    end

    it "returns 404 for a run from another workflow" do
      post "#{base_path}.json",
           params: {
             execution_id: Fabricate(:discourse_workflows_completed_execution).id,
           }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PUT update" do
    it "updates checks and pasted responses" do
      put "#{base_path}/#{workflow_test.id}.json",
          params: {
            checks: [{ effect: "finishes" }, { effect: "nothing" }],
            pasted_responses: {
              "Call API" => {
                "ok" => true,
              },
            },
          }

      expect(response).to have_http_status(:ok)
      test = response.parsed_body["test"]
      expect(test["checks"].map { |check| check["effect"] }).to eq(%w[finishes nothing])
      expect(test["steps_needing_response"]).to eq([])
    end

    it "returns 422 for invalid checks" do
      put "#{base_path}/#{workflow_test.id}.json", params: { checks: [{ effect: "chat_message" }] }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["errors"].first).to include("not something a test can check")
    end
  end

  describe "DELETE destroy" do
    it "deletes the test" do
      delete "#{base_path}/#{workflow_test.id}.json"

      expect(response).to have_http_status(:no_content)
      expect(DiscourseWorkflows::WorkflowTest.exists?(workflow_test.id)).to be(false)
    end
  end

  describe "POST run" do
    it "enqueues a simulation per test" do
      post "#{base_path}/run.json", params: { test_ids: [workflow_test.id] }

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["executions"].first).to include(
        "workflow_test_id" => workflow_test.id,
      )
      expect(Jobs::DiscourseWorkflows::RunSimulation.jobs.size).to eq(1)
    end

    it "returns 422 when a test has no checks" do
      workflow_test.update_columns(checks: [])

      post "#{base_path}/run.json"

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["errors"]).to eq(
        ["Add at least one check before running this test."],
      )
    end

    it "enforces the simulation quota" do
      SiteSetting.discourse_workflows_max_simulations_per_hour = 1
      RateLimiter.enable

      freeze_time do
        post "#{base_path}/run.json"
        expect(response).to have_http_status(:created)
        post "#{base_path}/run.json"
        expect(response).to have_http_status(:too_many_requests)
      end
    ensure
      RateLimiter.disable
    end
  end

  describe "POST refresh" do
    it "clears captured data and enqueues a run" do
      workflow_test.update!(captured_at: 1.day.ago)

      post "#{base_path}/#{workflow_test.id}/refresh.json"

      expect(response).to have_http_status(:created)
      expect(workflow_test.reload.captured_at).to be_nil
      expect(Jobs::DiscourseWorkflows::RunSimulation.jobs.size).to eq(1)
    end
  end
end
