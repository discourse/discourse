# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::WebhooksController do
  fab!(:admin)

  fab!(:workflow) { Fabricate(:discourse_workflows_workflow, created_by: admin, enabled: true) }

  fab!(:webhook_node) do
    Fabricate(
      :discourse_workflows_node,
      workflow: workflow,
      type: "trigger:webhook",
      name: "Webhook",
      configuration: {
        "path" => "my-hook",
        "http_method" => "POST",
      },
    )
  end

  before { SiteSetting.discourse_workflows_enabled = true }

  describe "POST /workflows/webhooks/:path" do
    it "enqueues workflow execution for matching webhook" do
      post "/workflows/webhooks/my-hook.json",
           params: { foo: "bar" }.to_json,
           headers: {
             "CONTENT_TYPE" => "application/json",
           }

      expect(response.status).to eq(200)
      expect(response.parsed_body["success"]).to eq(true)

      job = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last
      expect(job["args"][0]["trigger_node_id"]).to eq(webhook_node.id)

      trigger_data = job["args"][0]["trigger_data"]
      expect(trigger_data["body"]).to eq({ "foo" => "bar" })
      expect(trigger_data["query"]).to be_a(Hash)
      expect(trigger_data["headers"]).to be_a(Hash)
    end

    it "returns 404 when no matching webhook exists" do
      post "/workflows/webhooks/unknown-path.json"
      expect(response.status).to eq(404)
    end

    it "returns 404 when HTTP method does not match" do
      get "/workflows/webhooks/my-hook.json"
      expect(response.status).to eq(404)
    end

    it "returns 404 when workflow is disabled" do
      workflow.update!(enabled: false)
      post "/workflows/webhooks/my-hook.json"
      expect(response.status).to eq(404)
    end

    it "returns 404 when plugin is disabled" do
      SiteSetting.discourse_workflows_enabled = false
      post "/workflows/webhooks/my-hook.json"
      expect(response.status).to eq(404)
    end

    it "works without authentication" do
      post "/workflows/webhooks/my-hook.json",
           params: { data: "test" }.to_json,
           headers: {
             "CONTENT_TYPE" => "application/json",
           }

      expect(response.status).to eq(200)
    end

    it "passes query parameters in trigger data" do
      post "/workflows/webhooks/my-hook.json?source=github&ref=main",
           params: {}.to_json,
           headers: {
             "CONTENT_TYPE" => "application/json",
           }

      expect(response.status).to eq(200)

      trigger_data = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last["args"][0]["trigger_data"]
      expect(trigger_data["query"]["source"]).to eq("github")
      expect(trigger_data["query"]["ref"]).to eq("main")
    end

    it "handles different HTTP methods" do
      webhook_node.update!(configuration: { "path" => "my-hook", "http_method" => "PUT" })

      put "/workflows/webhooks/my-hook.json",
          params: { updated: true }.to_json,
          headers: {
            "CONTENT_TYPE" => "application/json",
          }

      expect(response.status).to eq(200)
    end

    it "handles non-JSON content type" do
      post "/workflows/webhooks/my-hook.json", params: { data: "test" }

      expect(response.status).to eq(200)

      trigger_data = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last["args"][0]["trigger_data"]
      expect(trigger_data["body"]).to eq({ "data" => "test" })
    end
  end
end
