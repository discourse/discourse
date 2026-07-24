# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::ActiveWebhooks do
  fab!(:admin)

  before { described_class.reset_for_tests! }
  after { described_class.reset_for_tests! }

  def make_workflow(path:, http_method:, webhook_id: nil)
    graph =
      build_workflow_graph do |g|
        g.node "webhook-1",
               "trigger:webhook",
               webhook_id: webhook_id,
               configuration: {
                 "path" => path,
                 "http_method" => http_method,
               }
      end
    workflow = Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
    version = workflow.workflow_versions.find_by(version_id: workflow.version_id)
    DiscourseWorkflows::Webhook::Action::ActivateWebhooks.call(
      workflow: workflow,
      workflow_version: version,
    )
    workflow
  end

  describe ".find" do
    it "matches static paths exactly with empty path_params" do
      make_workflow(path: "hooks/inbound", http_method: "POST")

      result = described_class.find(method: "POST", path: "hooks/inbound", test_webhook: false)

      expect(result[:webhook].webhook_path).to eq("hooks/inbound")
      expect(result[:path_params]).to eq({})
    end

    it "returns nil when the method does not match" do
      make_workflow(path: "hooks/inbound", http_method: "POST")

      expect(
        described_class.find(method: "GET", path: "hooks/inbound", test_webhook: false),
      ).to be_nil
    end

    it "matches dynamic paths by webhook_id prefix and captures path params" do
      make_workflow(path: "users/:id/posts", http_method: "GET", webhook_id: "abcd-1234")

      result =
        described_class.find(method: "GET", path: "abcd-1234/users/42/posts", test_webhook: false)

      expect(result[:webhook].webhook_id).to eq("abcd-1234")
      expect(result[:path_params]).to eq("id" => "42")
    end

    it "prefers the longest template when several share the same webhook_id" do
      graph =
        build_workflow_graph do |g|
          g.node "webhook-1",
                 "trigger:webhook",
                 webhook_id: "abcd-1234",
                 configuration: {
                   "path" => "users/:id/posts/:post_id",
                   "http_method" => "GET",
                 }
          g.node "webhook-2",
                 "trigger:webhook",
                 webhook_id: "abcd-1234",
                 configuration: {
                   "path" => "users/:id",
                   "http_method" => "GET",
                 }
        end
      workflow =
        Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
      version = workflow.workflow_versions.find_by(version_id: workflow.version_id)
      DiscourseWorkflows::Webhook::Action::ActivateWebhooks.call(
        workflow: workflow,
        workflow_version: version,
      )

      result =
        described_class.find(method: "GET", path: "abcd-1234/users/9/posts/12", test_webhook: false)

      expect(result[:webhook].webhook_path).to eq("users/:id/posts/:post_id")
      expect(result[:path_params]).to eq("id" => "9", "post_id" => "12")
    end

    it "is invalidated when webhook rows change" do
      make_workflow(path: "hooks/before", http_method: "POST")
      expect(
        described_class.find(method: "POST", path: "hooks/before", test_webhook: false),
      ).to be_present

      DiscourseWorkflows::Webhook.production.delete_all
      described_class.invalidate!

      expect(
        described_class.find(method: "POST", path: "hooks/before", test_webhook: false),
      ).to be_nil
    end
  end
end
