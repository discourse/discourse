# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::PublishedTrigger do
  fab!(:admin)
  fab!(:user)

  let(:type) { "trigger:manual" }

  def workflow_with_trigger(published:, name: "Support desk")
    graph =
      build_workflow_graph do |builder|
        builder.node("start", "trigger:manual", configuration: { "note" => "from the graph" })
        builder.node("other_start", "trigger:manual")
        builder.node("log", "action:log")
        builder.connect("start", "log")
      end
    Fabricate(:discourse_workflows_workflow, published:, name:, **graph)
  end

  describe ".find" do
    it "returns that node of that workflow's published version" do
      workflow_with_trigger(published: true, name: "Another workflow")
      workflow = workflow_with_trigger(published: true)
      workflow_with_trigger(published: true, name: "Yet another workflow")

      trigger = described_class.find(type:, workflow_id: workflow.id, node_id: "start")
      other_trigger = described_class.find(type:, workflow_id: workflow.id, node_id: "other_start")

      expect(other_trigger).to have_attributes(workflow:, trigger_node_id: "other_start")
      expect(trigger).to have_attributes(
        workflow:,
        workflow_version: workflow.active_version,
        trigger_node_id: "start",
        draft?: false,
        parameters: {
          "note" => "from the graph",
        },
        node_type: DiscourseWorkflows::Nodes::Manual::V1,
        workflow_name: "Support desk",
      )
    end

    it "names a published trigger after its version, not the renamed draft" do
      workflow = workflow_with_trigger(published: true)
      workflow.update!(name: "Renamed draft")

      trigger = described_class.find(type:, workflow_id: workflow.id, node_id: "start")

      expect(trigger.workflow_name).to eq("Support desk")
    end

    it "returns nil for a workflow that is not published" do
      workflow = workflow_with_trigger(published: false)

      expect(described_class.find(type:, workflow_id: workflow.id, node_id: "start")).to be_nil
    end

    it "returns nil when the node is of another type" do
      workflow = workflow_with_trigger(published: true)

      expect(
        described_class.find(type: "trigger:webhook", workflow_id: workflow.id, node_id: "start"),
      ).to be_nil
      expect(described_class.find(type:, workflow_id: workflow.id, node_id: "log")).to be_nil
    end

    it "returns nil for a blank workflow or node ID instead of any trigger of that type" do
      workflow = workflow_with_trigger(published: true)

      [nil, ""].each do |blank|
        expect(described_class.find(type:, workflow_id: blank, node_id: "start")).to be_nil
        expect(described_class.find(type:, workflow_id: workflow.id, node_id: blank)).to be_nil
        expect(
          described_class.find(
            type:,
            workflow_id: blank,
            node_id: "start",
            draft: true,
            guardian: admin.guardian,
          ),
        ).to be_nil
      end
    end

    it "returns the draft's trigger to a guardian who can manage workflows" do
      workflow = workflow_with_trigger(published: false)

      trigger =
        described_class.find(
          type:,
          workflow_id: workflow.id,
          node_id: "start",
          draft: true,
          guardian: admin.guardian,
        )

      expect(trigger).to have_attributes(
        workflow:,
        workflow_version: nil,
        trigger_node_id: "start",
        draft?: true,
        parameters: {
          "note" => "from the graph",
        },
        node_type: DiscourseWorkflows::Nodes::Manual::V1,
        workflow_name: "Support desk",
      )
    end

    it "returns nil for a draft node of another type" do
      workflow = workflow_with_trigger(published: false)

      expect(
        described_class.find(
          type:,
          workflow_id: workflow.id,
          node_id: "log",
          draft: true,
          guardian: admin.guardian,
        ),
      ).to be_nil
    end

    it "returns nil for a draft when the guardian cannot manage workflows" do
      workflow = workflow_with_trigger(published: true)

      [user.guardian, Guardian.new, nil].each do |guardian|
        expect(
          described_class.find(
            type:,
            workflow_id: workflow.id,
            node_id: "start",
            draft: true,
            guardian:,
          ),
        ).to be_nil
      end
    end
  end
end
