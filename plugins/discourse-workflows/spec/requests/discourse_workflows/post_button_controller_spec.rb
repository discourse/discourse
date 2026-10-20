# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::PostButtonController do
  fab!(:group)
  fab!(:member) { Fabricate(:user).tap { |user| group.add(user) } }
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
    Fabricate(:discourse_workflows_workflow, published: true, **graph)
  end

  let(:params) do
    { workflow_id: workflow.id, trigger_node_id: "trigger-1", post_id: post_record.id }
  end

  describe "POST /discourse-workflows/trigger-post-button" do
    it "requires authentication" do
      post "/discourse-workflows/trigger-post-button.json", params: params

      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 when the user is in none of the configured groups" do
      sign_in(Fabricate(:user))

      post "/discourse-workflows/trigger-post-button.json", params: params

      expect(response).to have_http_status(:forbidden)
    end

    context "when signed in as a group member" do
      before { sign_in(member) }

      it "returns 204 on success" do
        post "/discourse-workflows/trigger-post-button.json", params: params

        expect(response).to have_http_status(:no_content)
      end

      it "returns 400 when contract is invalid" do
        post "/discourse-workflows/trigger-post-button.json", params: {}

        expect(response).to have_http_status(:bad_request)
      end

      it "returns 404 when trigger node does not exist" do
        post "/discourse-workflows/trigger-post-button.json",
             params: params.merge(trigger_node_id: "nonexistent")

        expect(response).to have_http_status(:not_found)
      end

      it "returns 404 when the user cannot see the post" do
        category = Fabricate(:private_category, group: Fabricate(:group))
        private_post = Fabricate(:post, topic: Fabricate(:topic, category:))

        post "/discourse-workflows/trigger-post-button.json",
             params: params.merge(post_id: private_post.id)

        expect(response).to have_http_status(:not_found)
      end

      it "returns 403 when the configured post number does not match" do
        update_workflow_node(workflow, "trigger-1") do |node|
          node.deep_merge("parameters" => { "post_number" => post_record.post_number + 1 })
        end
        publish_workflow!(workflow)

        post "/discourse-workflows/trigger-post-button.json", params: params

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
