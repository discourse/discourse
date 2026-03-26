# frozen_string_literal: true

RSpec.describe SiteSerializer do
  fab!(:admin)
  let(:guardian) { Guardian.new(admin) }

  before { SiteSetting.discourse_workflows_enabled = true }

  describe "#topic_admin_button_workflows" do
    fab!(:workflow) { Fabricate(:discourse_workflows_workflow, created_by: admin, enabled: true) }
    fab!(:trigger_node) do
      Fabricate(
        :discourse_workflows_node,
        workflow: workflow,
        type: "trigger:topic_admin_button",
        name: "Topic Admin Button",
        configuration: {
          "label" => "Run workflow",
          "icon" => "bolt",
        },
      )
    end

    it "includes enabled topic admin button workflows" do
      data = described_class.new(Site.new(guardian), scope: guardian, root: false).as_json

      expect(data[:topic_admin_button_workflows]).to contain_exactly(
        {
          trigger_node_id: trigger_node.id,
          workflow_id: workflow.id,
          label: "Run workflow",
          icon: "bolt",
        },
      )
    end

    it "uses gear as default icon" do
      trigger_node.update!(configuration: { "label" => "Run workflow" })

      data = described_class.new(Site.new(guardian), scope: guardian, root: false).as_json

      expect(data[:topic_admin_button_workflows].first[:icon]).to eq("gear")
    end

    it "excludes disabled workflows" do
      workflow.update!(enabled: false)

      data = described_class.new(Site.new(guardian), scope: guardian, root: false).as_json

      expect(data[:topic_admin_button_workflows]).to be_empty
    end
  end
end
