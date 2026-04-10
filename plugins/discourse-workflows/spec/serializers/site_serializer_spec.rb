# frozen_string_literal: true

RSpec.describe SiteSerializer do
  fab!(:admin)
  let(:guardian) { Guardian.new(admin) }

  describe "#topic_admin_button_workflows" do
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
      Fabricate(:discourse_workflows_workflow, created_by: admin, enabled: true, **graph)
    end

    it "includes enabled topic admin button workflows" do
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

    it "keeps the icon empty when none is configured" do
      workflow.update!(
        nodes:
          workflow.parsed_nodes.map do |n|
            if n["id"] == "trigger-1"
              n.merge("configuration" => { "label" => "Run workflow" })
            else
              n
            end
          end,
      )

      data = described_class.new(Site.new(guardian), scope: guardian, root: false).as_json

      expect(data[:topic_admin_button_workflows].first[:icon]).to be_nil
    end

    it "excludes disabled workflows" do
      workflow.update!(enabled: false)

      data = described_class.new(Site.new(guardian), scope: guardian, root: false).as_json

      expect(data[:topic_admin_button_workflows]).to be_empty
    end
  end
end
