# frozen_string_literal: true

RSpec.describe DiscourseAi::PersonaExporter do
  before { enable_current_plugin }

  describe "#export" do
    subject(:export_json) { JSON.parse(exporter.export) }

    context "when exporting a persona with a custom tool" do
      fab!(:ai_tool) { Fabricate(:ai_tool, name: "Giphy Searcher", tool_name: "giphy_search") }
      fab!(:ai_persona) { Fabricate(:ai_persona, tools: [["custom-#{ai_tool.id}", nil, false]]) }

      let(:exporter) { described_class.new(persona: ai_persona) }

      it "returns JSON containing the persona and its custom tool" do
        expect(export_json["persona"]["name"]).to eq(ai_persona.name)
        expect(export_json["persona"]["tools"].first.first).to eq("custom-#{ai_tool.tool_name}")

        custom_tool = export_json["custom_tools"].first
        expect(custom_tool["identifier"]).to eq(ai_tool.tool_name)
        expect(custom_tool["name"]).to eq(ai_tool.name)
      end
    end

    context "when the persona has no custom tools" do
      fab!(:ai_persona) { Fabricate(:ai_persona, tools: []) }
      let(:exporter) { described_class.new(persona: ai_persona) }

      it "returns JSON with an empty custom_tools array" do
        expect(export_json["custom_tools"]).to eq([])
      end
    end

    context "when the persona does not exist" do
      it "raises an error if initialized with a non persona" do
        expect { described_class.new(persona: nil) }.to raise_error(
          ArgumentError,
          "Invalid persona provided",
        )
      end
    end
  end
end
