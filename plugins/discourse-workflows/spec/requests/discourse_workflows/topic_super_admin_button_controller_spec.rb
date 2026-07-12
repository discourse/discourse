# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::TopicSuperAdminButtonController do
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
    Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
  end

  describe "POST /discourse-workflows/trigger-topic-admin-button" do
    it "requires authentication" do
      post "/discourse-workflows/trigger-topic-admin-button.json",
           params: {
             trigger_node_id: "trigger-1",
             topic_id: topic.id,
           }

      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 when user is not an admin" do
      sign_in(user)

      post "/discourse-workflows/trigger-topic-admin-button.json",
           params: {
             trigger_node_id: "trigger-1",
             topic_id: topic.id,
           }

      expect(response).to have_http_status(:forbidden)
    end

    context "when signed in as admin" do
      before { sign_in(admin) }

      it "returns 204 on success" do
        post "/discourse-workflows/trigger-topic-admin-button.json",
             params: {
               trigger_node_id: "trigger-1",
               topic_id: topic.id,
             }

        expect(response).to have_http_status(:no_content)
      end

      it "enqueues an ExecuteWorkflow job" do
        post "/discourse-workflows/trigger-topic-admin-button.json",
             params: {
               trigger_node_id: "trigger-1",
               topic_id: topic.id,
             }

        job = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last
        expect(job["args"].first).to include(
          "trigger_node_id" => "trigger-1",
          "workflow_version_id" => workflow.active_version_id,
        )
      end

      it "returns 400 when contract is invalid" do
        post "/discourse-workflows/trigger-topic-admin-button.json", params: {}

        expect(response).to have_http_status(:bad_request)
      end

      it "returns 404 when trigger node does not exist" do
        post "/discourse-workflows/trigger-topic-admin-button.json",
             params: {
               trigger_node_id: "nonexistent",
               topic_id: topic.id,
             }

        expect(response).to have_http_status(:not_found)
      end

      it "returns 404 when workflow is unpublished" do
        unpublish_workflow!(workflow)

        post "/discourse-workflows/trigger-topic-admin-button.json",
             params: {
               trigger_node_id: "trigger-1",
               topic_id: topic.id,
             }

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
