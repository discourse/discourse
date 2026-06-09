# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::WebhookTestListenersController do
  fab!(:admin)
  fab!(:workflow) do
    graph =
      build_workflow_graph do |g|
        g.node "webhook-1",
               "trigger:webhook",
               configuration: {
                 "path" => "test-hook",
                 "http_method" => "POST",
               }
      end
    Fabricate(:discourse_workflows_workflow, created_by: admin, published: false, **graph)
  end

  describe "POST /admin/plugins/discourse-workflows/workflows/:id/webhook-test-listeners.json" do
    it "requires an admin" do
      sign_in(Fabricate(:user))

      post "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/webhook-test-listeners.json",
           params: {
             trigger_node_id: "webhook-1",
           }

      expect(response).to have_http_status(:not_found)
    end

    it "creates a short-lived webhook test listener" do
      sign_in(admin)

      post "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/webhook-test-listeners.json",
           params: {
             trigger_node_id: "webhook-1",
           }

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include(
        "listener_id" => match(/\A[0-9a-f-]{36}\z/),
        "test_url" => match(%r{\A/workflows/webhook-test/[0-9a-f-]{36}/test-hook\z}),
        "expires_at" => be_present,
      )
    end
  end

  describe "DELETE /admin/plugins/discourse-workflows/workflows/:id/webhook-test-listeners/:listener_id.json" do
    it "cancels the listener" do
      sign_in(admin)
      listener =
        DiscourseWorkflows::WebhookTestListener.create!(
          workflow: workflow,
          user: admin,
          trigger_node: workflow.find_node("webhook-1"),
        )

      delete "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/webhook-test-listeners/#{listener.listener_id}.json"

      expect(response).to have_http_status(:no_content)
      expect(DiscourseWorkflows::WebhookTestListener.find(listener.listener_id)).to be_nil
    end
  end
end
