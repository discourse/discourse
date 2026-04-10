# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::TopicAdminButtonController do
  fab!(:admin)
  fab!(:user)
  fab!(:topic)
  fab!(:workflow) do
    graph =
      build_workflow_graph do |g|
        g.node "trigger-1",
               "trigger:topic_admin_button",
               configuration: {
                 "label" => "Run workflow",
                 "icon" => "gear",
               }
      end
    Fabricate(:discourse_workflows_workflow, created_by: admin, enabled: true, **graph)
  end

  before { SiteSetting.discourse_workflows_enabled = true }

  describe "POST /discourse-workflows/trigger-topic-admin-button" do
    it "requires authentication" do
      post "/discourse-workflows/trigger-topic-admin-button.json",
           params: {
             trigger_node_id: "trigger-1",
             topic_id: topic.id,
           }

      expect(response.status).to eq(403)
    end

    it "returns 204 on success" do
      sign_in(admin)

      post "/discourse-workflows/trigger-topic-admin-button.json",
           params: {
             trigger_node_id: "trigger-1",
             topic_id: topic.id,
           }

      expect(response.status).to eq(204)
    end

    it "enqueues an ExecuteWorkflow job" do
      sign_in(admin)

      post "/discourse-workflows/trigger-topic-admin-button.json",
           params: {
             trigger_node_id: "trigger-1",
             topic_id: topic.id,
           }

      job = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last
      expect(job["args"].first["trigger_node_id"]).to eq("trigger-1")
    end

    it "returns 400 when contract is invalid" do
      sign_in(admin)

      post "/discourse-workflows/trigger-topic-admin-button.json", params: {}

      expect(response.status).to eq(400)
    end

    it "returns 404 when trigger node does not exist" do
      sign_in(admin)

      post "/discourse-workflows/trigger-topic-admin-button.json",
           params: {
             trigger_node_id: "nonexistent",
             topic_id: topic.id,
           }

      expect(response.status).to eq(404)
    end

    it "returns 403 when user is not an admin" do
      sign_in(user)

      post "/discourse-workflows/trigger-topic-admin-button.json",
           params: {
             trigger_node_id: "trigger-1",
             topic_id: topic.id,
           }

      expect(response.status).to eq(403)
    end

    it "returns 404 when workflow is disabled" do
      sign_in(admin)
      workflow.update!(enabled: false)

      post "/discourse-workflows/trigger-topic-admin-button.json",
           params: {
             trigger_node_id: "trigger-1",
             topic_id: topic.id,
           }

      expect(response.status).to eq(404)
    end
  end
end
