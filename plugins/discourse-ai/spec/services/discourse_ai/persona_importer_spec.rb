# frozen_string_literal: true

RSpec.describe DiscourseAi::PersonaImporter do
  before { enable_current_plugin }

  describe "#import!" do
    context "when importing a persona with a custom tool" do
      fab!(:ai_tool) { Fabricate(:ai_tool, name: "Giphy Searcher", tool_name: "giphy_search") }
      fab!(:ai_persona) { Fabricate(:ai_persona, tools: [["custom-#{ai_tool.id}", nil, false]]) }

      let!(:export_json) { DiscourseAi::PersonaExporter.new(persona: ai_persona).export }

      it "creates the persona and its custom tool" do
        ai_persona.destroy
        ai_tool.destroy

        importer = described_class.new(json: export_json)
        persona = importer.import!

        expect(persona).to be_persisted
        expect(persona.tools.first.first).to start_with("custom-")

        tool_id = persona.tools.first.first.split("-", 2).last.to_i
        imported_tool = AiTool.find(tool_id)

        expect(imported_tool.tool_name).to eq("giphy_search")
        expect(imported_tool.name).to eq("Giphy Searcher")
      end
    end

    context "when conflicts exist" do
      fab!(:existing_tool) { Fabricate(:ai_tool, name: "Web Browser", tool_name: "browse_web") }
      fab!(:another_tool) { Fabricate(:ai_tool, name: "Calculator", tool_name: "calculator") }
      fab!(:ai_persona) do
        Fabricate(
          :ai_persona,
          name: "Test Persona",
          tools: [
            ["custom-#{existing_tool.id}", nil, false],
            ["custom-#{another_tool.id}", nil, false],
          ],
        )
      end

      let(:export_json) { DiscourseAi::PersonaExporter.new(persona: ai_persona).export }

      context "when persona already exists" do
        it "raises ImportError with persona conflict details" do
          importer = described_class.new(json: export_json)

          expect { importer.import! }.to raise_error(
            DiscourseAi::PersonaImporter::ImportError,
          ) do |error|
            expect(error.conflicts).to eq(
              persona: "Test Persona",
              custom_tools: %w[browse_web calculator],
            )
          end
        end
      end

      context "when custom tools already exist" do
        before { ai_persona.destroy }

        it "raises ImportError with custom tools conflict details" do
          importer = described_class.new(json: export_json)

          expect { importer.import! }.to raise_error(
            DiscourseAi::PersonaImporter::ImportError,
          ) do |error|
            expect(error.conflicts[:custom_tools]).to contain_exactly("browse_web", "calculator")
          end
        end
      end

      context "when both persona and custom tools exist" do
        it "raises ImportError with all conflicts" do
          importer = described_class.new(json: export_json)

          expect { importer.import! }.to raise_error(
            DiscourseAi::PersonaImporter::ImportError,
          ) do |error|
            expect(error.conflicts[:persona]).to eq("Test Persona")
            expect(error.conflicts[:custom_tools]).to contain_exactly("browse_web", "calculator")
          end
        end
      end
    end

    context "with overwrite: true" do
      fab!(:existing_tool) { Fabricate(:ai_tool, name: "Old Browser", tool_name: "browse_web") }
      fab!(:existing_persona) do
        Fabricate(
          :ai_persona,
          name: "Test Persona",
          description: "Old description",
          system_prompt: "Old prompt",
          tools: [],
        )
      end
      fab!(:new_tool) { Fabricate(:ai_tool, name: "New Tool", tool_name: "new_tool") }
      let(:export_persona) do
        Fabricate.build(
          :ai_persona,
          name: "Test Persona",
          description: "New description",
          system_prompt: "New prompt",
          tools: [
            ["custom-#{existing_tool.id}", nil, false],
            ["custom-#{new_tool.id}", nil, false],
          ],
        )
      end

      let(:export_json) { DiscourseAi::PersonaExporter.new(persona: export_persona).export }

      before { export_persona.destroy }

      it "overwrites existing persona" do
        importer = described_class.new(json: export_json)
        persona = importer.import!(overwrite: true)

        expect(persona.id).to eq(existing_persona.id)
        expect(persona.description).to eq("New description")
        expect(persona.system_prompt).to eq("New prompt")
        expect(persona.tools.length).to eq(2)
      end

      it "overwrites existing custom tools" do
        existing_tool.update!(name: "Old Browser", description: "Old description")

        importer = described_class.new(json: export_json)
        expect { importer.import!(overwrite: true) }.not_to change { AiTool.count }

        existing_tool.reload
        expect(existing_tool.name).to eq("Old Browser") # Name from export_json
      end
    end

    context "with invalid payload" do
      it "raises an error for invalid JSON structure" do
        expect { described_class.new(json: "{}").import! }.to raise_error(
          ArgumentError,
          "Invalid persona export data",
        )
      end

      it "raises an error for missing persona data" do
        expect { described_class.new(json: { "custom_tools" => [] }).import! }.to raise_error(
          ArgumentError,
          "Invalid persona export data",
        )
      end
    end
  end
end
