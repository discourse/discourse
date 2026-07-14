# frozen_string_literal: true

RSpec.describe SiteSerializer do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)
  let(:guardian) { Guardian.new(admin) }

  describe "#topic_admin_button_workflows" do
    before { DiscourseWorkflows::WorkflowDependency.clear_cache! }

    fab!(:workflow) do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1",
                 "trigger:topic_admin_button",
                 configuration: {
                   "label" => "Run workflow",
                   "icon" => "bolt",
                 }
        end
      Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
    end

    it "includes published topic admin button workflows" do
      data = described_class.new(Site.new(guardian), scope: guardian, root: false).as_json

      expect(data[:topic_admin_button_workflows]).to contain_exactly(
        {
          trigger_node_id: "trigger-1",
          workflow_id: workflow.id,
          label: "Run workflow",
          icon: "bolt",
        },
      )
    end

    it "is not included for moderators" do
      mod_guardian = Guardian.new(moderator)
      data = described_class.new(Site.new(mod_guardian), scope: mod_guardian, root: false).as_json

      expect(data).not_to have_key(:topic_admin_button_workflows)
    end

    it "is not included for regular users" do
      user_guardian = Guardian.new(user)
      data = described_class.new(Site.new(user_guardian), scope: user_guardian, root: false).as_json

      expect(data).not_to have_key(:topic_admin_button_workflows)
    end

    it "keeps the icon empty when none is configured" do
      update_workflow_node(workflow, "trigger-1") do |node|
        node.merge("parameters" => { "label" => "Run workflow" })
      end
      publish_workflow!(workflow)

      data = described_class.new(Site.new(guardian), scope: guardian, root: false).as_json

      expect(data[:topic_admin_button_workflows].first[:icon]).to be_nil
    end

    it "excludes unpublished workflows" do
      unpublish_workflow!(workflow)
      DiscourseWorkflows::WorkflowDependency.clear_cache!

      data = described_class.new(Site.new(guardian), scope: guardian, root: false).as_json

      expect(data[:topic_admin_button_workflows]).to be_empty
    end
  end
end
