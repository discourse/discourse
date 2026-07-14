# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor::TriggerExecutionContext do
  fab!(:workflow) do
    graph =
      build_workflow_graph do |g|
        g.node "trigger-1",
               "trigger:schedule",
               configuration: {
                 rule: {
                   interval: [{ field: "days" }],
                 },
               }
      end
    Fabricate(
      :discourse_workflows_workflow,
      published: true,
      settings: {
        "timezone" => "Europe/Paris",
      },
      **graph,
    )
  end

  let(:trigger_node) { workflow.active_version.nodes.first }
  let(:published_trigger) do
    DiscourseWorkflows::PublishedTrigger.new(
      workflow:,
      workflow_version: workflow.active_version,
      trigger_node:,
    )
  end
  let(:runtime_state) do
    described_class::RuntimeState.new(
      trigger_state: workflow.node_trigger_state(trigger_node["id"]).deep_dup,
      static_data_global: workflow.global_static_data.deep_dup,
      static_data_node: workflow.node_static_data(trigger_node["name"]).deep_dup,
    )
  end
  let(:ctx) { described_class.new(published_trigger:, runtime_state:) }

  describe "#get_timezone" do
    it "returns the resolved workflow timezone" do
      expect(ctx.get_timezone).to eq("Europe/Paris")
    end
  end

  describe "#get_workflow_static_data" do
    it "returns the node-scoped hash for :node" do
      expect(ctx.get_workflow_static_data(:node)).to equal(runtime_state.static_data_node)
    end

    it "returns the global hash for :global" do
      expect(ctx.get_workflow_static_data(:global)).to equal(runtime_state.static_data_global)
    end

    it "raises on unknown scopes" do
      expect { ctx.get_workflow_static_data(:bogus) }.to raise_error(ArgumentError)
    end
  end
end
