# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::ComposerPausedController do
  fab!(:admin)
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:workflow) do
    graph =
      build_workflow_graph do |g|
        g.node "trigger-1",
               "trigger:composer_paused",
               configuration: {
                 "phrases" => ["Magic words"],
               }
      end
    Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
  end

  let(:params) do
    {
      workflow_id: workflow.id,
      trigger_node_id: "trigger-1",
      draft_key: "new_topic",
      session_id: "session-1",
      composer_action: "create_topic",
      raw: "Maybe I should just say the Magic words",
    }
  end

  describe "POST /discourse-workflows/trigger-composer-paused" do
    it "requires authentication" do
      post "/discourse-workflows/trigger-composer-paused.json", params: params

      expect(response).to have_http_status(:forbidden)
    end

    context "when signed in" do
      before { sign_in(user) }

      it "returns 204 and enqueues the workflow" do
        expect {
          post "/discourse-workflows/trigger-composer-paused.json", params: params
        }.to change { Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size }.by(1)

        expect(response).to have_http_status(:no_content)
      end

      it "returns 400 when the contract is invalid" do
        post "/discourse-workflows/trigger-composer-paused.json", params: params.except(:draft_key)

        expect(response).to have_http_status(:bad_request)
      end

      it "returns 404 when the trigger does not exist" do
        post "/discourse-workflows/trigger-composer-paused.json",
             params: params.merge(trigger_node_id: "nonexistent")

        expect(response).to have_http_status(:not_found)
      end

      it "returns 403 when the user can't fire the trigger" do
        post "/discourse-workflows/trigger-composer-paused.json",
             params: params.merge(composer_action: "reply", topic_id: -1)

        expect(response).to have_http_status(:forbidden)
      end

      it "returns 422 when no phrase matches" do
        post "/discourse-workflows/trigger-composer-paused.json",
             params: params.merge(raw: "Nothing to see")

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns 422 when the phrases already fired in this session" do
        post "/discourse-workflows/trigger-composer-paused.json", params: params
        post "/discourse-workflows/trigger-composer-paused.json", params: params

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "is rate limited" do
        RateLimiter.enable
        stub_const(DiscourseWorkflows::ComposerPausedClaims, "RATE_LIMIT", 1) do
          post "/discourse-workflows/trigger-composer-paused.json", params: params
          post "/discourse-workflows/trigger-composer-paused.json", params: params
        end

        expect(response).to have_http_status(:too_many_requests)
      end
    end
  end
end
