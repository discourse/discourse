# frozen_string_literal: true

RSpec.describe DiscourseAi::AgentExporter do
  before { enable_current_plugin }

  describe "#export" do
    subject(:export_json) { JSON.parse(exporter.export) }

    context "when exporting a agent with a custom tool" do
      fab!(:ai_tool) { Fabricate(:ai_tool, name: "Giphy Searcher", tool_name: "giphy_search") }
      fab!(:ai_agent) { Fabricate(:ai_agent, tools: [["custom-#{ai_tool.id}", nil, false]]) }

      let(:exporter) { described_class.new(agent: ai_agent) }

      it "returns JSON containing the agent and its custom tool" do
        expect(export_json["agent"]["name"]).to eq(ai_agent.name)
        expect(export_json["agent"]["tools"].first.first).to eq("custom-#{ai_tool.tool_name}")

        custom_tool = export_json["custom_tools"].first
        expect(custom_tool["identifier"]).to eq(ai_tool.tool_name)
        expect(custom_tool["name"]).to eq(ai_tool.name)
        expect(custom_tool["secret_contracts"]).to eq(ai_tool.secret_contracts)
      end
    end

    context "when the agent has no custom tools" do
      fab!(:ai_agent) { Fabricate(:ai_agent, tools: []) }
      let(:exporter) { described_class.new(agent: ai_agent) }

      it "returns JSON with an empty custom_tools array" do
        expect(export_json["custom_tools"]).to eq([])
      end
    end

    context "when the agent does not exist" do
      it "raises an error if initialized with a non agent" do
        expect { described_class.new(agent: nil) }.to raise_error(
          ArgumentError,
          "Invalid agent provided",
        )
      end
    end
  end
end
