# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Webhook::Action::ActivateWebhooks do
  fab!(:admin)

  def build_published_workflow(path:, http_method:, webhook_id: nil)
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
    Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
  end

  describe ".call" do
    it "stores a row per webhook trigger in the active version" do
      workflow = build_published_workflow(path: "hooks/inbound", http_method: "POST")
      version = workflow.workflow_versions.find_by(version_id: workflow.version_id)

      described_class.call(workflow: workflow, workflow_version: version)

      row = DiscourseWorkflows::Webhook.production.find_by(workflow_id: workflow.id)
      expect(row).to have_attributes(
        webhook_path: "hooks/inbound",
        http_method: "POST",
        webhook_id: nil,
        path_length: nil,
        node_name: "Webhook-1",
        test_webhook: false,
      )
    end

    it "marks rows as dynamic when the path contains :placeholder segments" do
      workflow =
        build_published_workflow(
          path: "users/:id/posts",
          http_method: "GET",
          webhook_id: "abcd-1234",
        )
      version = workflow.workflow_versions.find_by(version_id: workflow.version_id)

      described_class.call(workflow: workflow, workflow_version: version)

      row = DiscourseWorkflows::Webhook.production.find_by(workflow_id: workflow.id)
      expect(row).to have_attributes(webhook_id: "abcd-1234", path_length: 3)
    end

    it "raises CollisionError when another workflow already owns the route" do
      owner = build_published_workflow(path: "shared", http_method: "POST")
      owner_version = owner.workflow_versions.find_by(version_id: owner.version_id)
      described_class.call(workflow: owner, workflow_version: owner_version)

      conflicting_graph =
        build_workflow_graph do |g|
          g.node "webhook-1",
                 "trigger:webhook",
                 configuration: {
                   "path" => "shared",
                   "http_method" => "POST",
                 }
        end
      other_workflow =
        Fabricate(
          :discourse_workflows_workflow,
          created_by: admin,
          published: false,
          **conflicting_graph,
        )
      other_workflow.update_columns(active_version_id: other_workflow.version_id)
      other_version =
        other_workflow.workflow_versions.find_by(version_id: other_workflow.version_id)

      expect do
        described_class.call(workflow: other_workflow, workflow_version: other_version)
      end.to raise_error(described_class::CollisionError) do |error|
        expect(error.method).to eq("POST")
        expect(error.path).to eq("shared")
      end
    end

    it "replaces this workflow's prior rows on re-activation" do
      workflow = build_published_workflow(path: "old", http_method: "POST")
      version = workflow.workflow_versions.find_by(version_id: workflow.version_id)
      described_class.call(workflow: workflow, workflow_version: version)

      updated_nodes = version.nodes.deep_dup
      updated_nodes.first["parameters"]["path"] = "new"
      version.update!(nodes: updated_nodes)

      described_class.call(workflow: workflow, workflow_version: version.reload)

      expect(
        DiscourseWorkflows::Webhook.production.where(workflow_id: workflow.id).pluck(:webhook_path),
      ).to eq(["new"])
    end
  end
end
