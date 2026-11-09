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
      draft_key: "new_topic",
      session_id: "session-1",
      composer_action: "create_topic",
      raw: "Maybe I should just say the Magic words",
    }
  end

  before { DiscourseWorkflows::WorkflowDependency.clear_cache! }

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

      it "returns 204 without firing when nothing matches" do
        expect {
          post "/discourse-workflows/trigger-composer-paused.json",
               params: params.merge(raw: "Nothing to see")
        }.not_to change { Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size }

        expect(response).to have_http_status(:no_content)
      end

      it "returns 429 when the rate limit runs out before every workflow fired" do
        graph =
          build_workflow_graph do |g|
            g.node "trigger-1", "trigger:composer_paused", configuration: {}
          end
        Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)

        RateLimiter.enable
        stub_const(DiscourseWorkflows::ComposerPausedClaims, "RATE_LIMIT", 1) do
          expect {
            post "/discourse-workflows/trigger-composer-paused.json", params: params
          }.to change { Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size }.by(1)
        end

        expect(response).to have_http_status(:too_many_requests)
        expect(response.parsed_body.dig("extras", "wait_seconds")).to be_present
      end

      it "limits requests that fire nothing" do
        RateLimiter.enable
        stub_const(DiscourseWorkflows::ComposerPausedClaims, "ATTEMPT_LIMIT", 1) do
          2.times do
            post "/discourse-workflows/trigger-composer-paused.json",
                 params: params.merge(raw: "Nothing to see")
          end
        end

        expect(response).to have_http_status(:too_many_requests)
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
