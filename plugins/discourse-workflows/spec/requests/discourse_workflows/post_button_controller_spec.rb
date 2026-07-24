# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::PostButtonController do
  fab!(:admin)
  fab!(:group)
  fab!(:member) { Fabricate(:user).tap { |user| group.add(user) } }
  fab!(:user)
  fab!(:post_record, :post)
  fab!(:workflow) do
    graph =
      build_workflow_graph do |g|
        g.node "trigger-1",
               "trigger:post_button",
               configuration: {
                 "label" => "Run workflow",
                 "icon" => "bolt",
                 "group_ids" => [group.id],
               }
      end
    Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
  end

  describe "POST /discourse-workflows/trigger-post-button" do
    it "requires authentication" do
      post "/discourse-workflows/trigger-post-button.json",
           params: {
             trigger_node_id: "trigger-1",
             post_id: post_record.id,
           }

      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 when the user is in none of the configured groups" do
      sign_in(user)

      post "/discourse-workflows/trigger-post-button.json",
           params: {
             trigger_node_id: "trigger-1",
             post_id: post_record.id,
           }

      expect(response).to have_http_status(:forbidden)
    end

    context "when signed in as a group member" do
      before { sign_in(member) }

      it "returns 204 on success" do
        post "/discourse-workflows/trigger-post-button.json",
             params: {
               trigger_node_id: "trigger-1",
               post_id: post_record.id,
             }

        expect(response).to have_http_status(:no_content)
      end

      it "enqueues an ExecuteWorkflow job" do
        post "/discourse-workflows/trigger-post-button.json",
             params: {
               trigger_node_id: "trigger-1",
               post_id: post_record.id,
             }

        job = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last
        expect(job["args"].first).to include(
          "trigger_node_id" => "trigger-1",
          "workflow_version_id" => workflow.active_version_id,
          "user_id" => member.id,
        )
      end

      it "returns 400 when contract is invalid" do
        post "/discourse-workflows/trigger-post-button.json", params: {}

        expect(response).to have_http_status(:bad_request)
      end

      it "returns 404 when trigger node does not exist" do
        post "/discourse-workflows/trigger-post-button.json",
             params: {
               trigger_node_id: "nonexistent",
               post_id: post_record.id,
             }

        expect(response).to have_http_status(:not_found)
      end

      it "returns 404 when workflow is unpublished" do
        unpublish_workflow!(workflow)

        post "/discourse-workflows/trigger-post-button.json",
             params: {
               trigger_node_id: "trigger-1",
               post_id: post_record.id,
             }

        expect(response).to have_http_status(:not_found)
      end

      it "returns 404 when the user cannot see the post" do
        private_category = Fabricate(:private_category, group: Fabricate(:group))
        private_post = Fabricate(:post, topic: Fabricate(:topic, category: private_category))

        post "/discourse-workflows/trigger-post-button.json",
             params: {
               trigger_node_id: "trigger-1",
               post_id: private_post.id,
             }

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
