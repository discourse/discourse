# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::TopicAdminButtonController do
  fab!(:admin)
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
    Fabricate(:discourse_workflows_workflow, published: true, **graph)
  end

  let(:params) { { trigger_node_id: "trigger-1", topic_id: topic.id } }

  describe "POST /discourse-workflows/trigger-topic-admin-button" do
    it "requires authentication" do
      post "/discourse-workflows/trigger-topic-admin-button.json", params: params

      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 when user is not an admin" do
      sign_in(Fabricate(:user))

      post "/discourse-workflows/trigger-topic-admin-button.json", params: params

      expect(response).to have_http_status(:forbidden)
    end

    context "when signed in as admin" do
      before { sign_in(admin) }

      it "returns 204 on success" do
        post "/discourse-workflows/trigger-topic-admin-button.json", params: params

        expect(response).to have_http_status(:no_content)
      end

      it "returns 400 when contract is invalid" do
        post "/discourse-workflows/trigger-topic-admin-button.json", params: {}

        expect(response).to have_http_status(:bad_request)
      end

      it "returns 404 when trigger node does not exist" do
        post "/discourse-workflows/trigger-topic-admin-button.json",
             params: params.merge(trigger_node_id: "nonexistent")

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
