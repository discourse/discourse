# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::ModalResponsesController do
  fab!(:user)
  fab!(:other_user, :user)

  fab!(:workflow) do
    graph =
      build_workflow_graph do |g|
        g.node "trigger-1", "trigger:manual", name: "Manual"
        g.node "modal-1",
               "action:modal",
               name: "Modal",
               configuration: {
                 "title" => "Approve topic?",
                 "target_user" => user.username,
                 "buttons" => {
                   "values" => [
                     { "label" => "Approve", "value" => "approve", "style" => "primary" },
                   ],
                 },
               }
        g.chain "trigger-1", "modal-1"
      end
    Fabricate(:discourse_workflows_workflow, name: "Published", published: true, **graph)
  end

  let(:execution) do
    DiscourseWorkflows::Executor.new(
      workflow,
      "trigger-1",
      {},
      DiscourseWorkflows::Executor::ExecutionOptions.new(user: user),
    ).run
  end

  let(:action_id) do
    DiscourseWorkflows::InteractiveResume.action_id(
      execution_id: execution.id,
      resume_token: execution.resume_token,
      action: "approve",
      target_user_id: user.id,
    )
  end
  let(:modal_id) { "abcd1234abcd1234" }

  describe "POST /discourse-workflows/modal-responses" do
    it "requires authentication" do
      post "/discourse-workflows/modal-responses.json", params: { action_id:, modal_id: }

      expect(response).to have_http_status(:forbidden)
    end

    context "when signed in as the modal's target user" do
      before { sign_in(user) }

      it "returns 204 and resumes the execution" do
        post "/discourse-workflows/modal-responses.json", params: { action_id:, modal_id: }

        expect(response).to have_http_status(:no_content)
        expect(execution.reload.status).to eq("success")
      end

      it "returns 204 when the modal was already handled" do
        post "/discourse-workflows/modal-responses.json", params: { action_id:, modal_id: }
        expect(response).to have_http_status(:no_content)

        post "/discourse-workflows/modal-responses.json", params: { action_id:, modal_id: }
        expect(response).to have_http_status(:no_content)
      end

      it "acknowledges a token with a forged signature without resuming anything" do
        post "/discourse-workflows/modal-responses.json",
             params: {
               action_id: "#{execution.id}:#{user.id}:approve:forged-signature",
               modal_id:,
             }

        # Indistinguishable from a stale token by design (uniform response, no
        # oracle); the crucial guarantee is that the execution is untouched.
        expect(response).to have_http_status(:no_content)
        expect(execution.reload.status).to eq("waiting")
      end

      it "returns 404 for a token that does not parse" do
        post "/discourse-workflows/modal-responses.json",
             params: {
               action_id: "not-a-token",
               modal_id:,
             }

        expect(response).to have_http_status(:not_found)
      end

      it "returns 400 for a blank action id" do
        post "/discourse-workflows/modal-responses.json", params: { action_id: "", modal_id: }

        expect(response).to have_http_status(:bad_request)
      end

      it "is rate limited" do
        RateLimiter.any_instance.expects(:performed!).raises(RateLimiter::LimitExceeded.new(60))

        # A static token: the rate limit check runs before the token is even
        # parsed, and building a real one would run the executor's own
        # rate-limited code under the mock above.
        post "/discourse-workflows/modal-responses.json",
             params: {
               action_id: "1:1:approve:sig",
               modal_id:,
             }

        expect(response).to have_http_status(:too_many_requests)
      end
    end

    context "when signed in as another user" do
      before { sign_in(other_user) }

      it "returns 404 and leaves the execution waiting" do
        post "/discourse-workflows/modal-responses.json", params: { action_id:, modal_id: }

        expect(response).to have_http_status(:not_found)
        expect(execution.reload.status).to eq("waiting")
      end
    end
  end
end
