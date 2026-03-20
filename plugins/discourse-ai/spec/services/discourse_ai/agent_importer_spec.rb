# frozen_string_literal: true

RSpec.describe DiscourseAi::AgentImporter do
  before { enable_current_plugin }

  describe "#import!" do
    context "when importing a agent with a custom tool" do
      fab!(:ai_tool) do
        Fabricate(
          :ai_tool,
          name: "Giphy Searcher",
          tool_name: "giphy_search",
          secret_contracts: [{ alias: "giphy_api_key" }],
        )
      end
      fab!(:ai_agent) { Fabricate(:ai_agent, tools: [["custom-#{ai_tool.id}", nil, false]]) }

      let!(:export_json) { DiscourseAi::AgentExporter.new(agent: ai_agent).export }

      it "creates the agent and its custom tool" do
        ai_agent.destroy
        ai_tool.destroy

        importer = described_class.new(json: export_json)
        agent = importer.import!

        expect(agent).to be_persisted
        expect(agent.tools.first.first).to start_with("custom-")

        tool_id = agent.tools.first.first.split("-", 2).last.to_i
        imported_tool = AiTool.find(tool_id)

        expect(imported_tool.tool_name).to eq("giphy_search")
        expect(imported_tool.name).to eq("Giphy Searcher")
        expect(imported_tool.secret_contracts).to eq([{ "alias" => "giphy_api_key" }])
      end
    end

    context "when conflicts exist" do
      fab!(:existing_tool) { Fabricate(:ai_tool, name: "Web Browser", tool_name: "browse_web") }
      fab!(:another_tool) { Fabricate(:ai_tool, name: "Calculator", tool_name: "calculator") }
      fab!(:ai_agent) do
        Fabricate(
          :ai_agent,
          name: "Test Agent",
          tools: [
            ["custom-#{existing_tool.id}", nil, false],
            ["custom-#{another_tool.id}", nil, false],
          ],
        )
      end

      let(:export_json) { DiscourseAi::AgentExporter.new(agent: ai_agent).export }

      context "when agent already exists" do
        it "raises ImportError with agent conflict details" do
          importer = described_class.new(json: export_json)

          expect { importer.import! }.to raise_error(
            DiscourseAi::AgentImporter::ImportError,
          ) do |error|
            expect(error.conflicts).to eq(
              agent: "Test Agent",
              custom_tools: %w[browse_web calculator],
            )
          end
        end
      end

      context "when custom tools already exist" do
        before { ai_agent.destroy }

        it "raises ImportError with custom tools conflict details" do
          importer = described_class.new(json: export_json)

          expect { importer.import! }.to raise_error(
            DiscourseAi::AgentImporter::ImportError,
          ) do |error|
            expect(error.conflicts[:custom_tools]).to contain_exactly("browse_web", "calculator")
          end
        end
      end

      context "when both agent and custom tools exist" do
        it "raises ImportError with all conflicts" do
          importer = described_class.new(json: export_json)

          expect { importer.import! }.to raise_error(
            DiscourseAi::AgentImporter::ImportError,
          ) do |error|
            expect(error.conflicts[:agent]).to eq("Test Agent")
            expect(error.conflicts[:custom_tools]).to contain_exactly("browse_web", "calculator")
          end
        end
      end
    end

    context "with overwrite: true" do
      fab!(:existing_tool) { Fabricate(:ai_tool, name: "Old Browser", tool_name: "browse_web") }
      fab!(:existing_agent) do
        Fabricate(
          :ai_agent,
          name: "Test Agent",
          description: "Old description",
          system_prompt: "Old prompt",
          tools: [],
        )
      end
      fab!(:new_tool) { Fabricate(:ai_tool, name: "New Tool", tool_name: "new_tool") }
      let(:export_agent) do
        Fabricate.build(
          :ai_agent,
          name: "Test Agent",
          description: "New description",
          system_prompt: "New prompt",
          tools: [
            ["custom-#{existing_tool.id}", nil, false],
            ["custom-#{new_tool.id}", nil, false],
          ],
        )
      end

      let(:export_json) { DiscourseAi::AgentExporter.new(agent: export_agent).export }

      before { export_agent.destroy }

      it "overwrites existing agent" do
        importer = described_class.new(json: export_json)
        agent = importer.import!(overwrite: true)

        expect(agent.id).to eq(existing_agent.id)
        expect(agent.description).to eq("New description")
        expect(agent.system_prompt).to eq("New prompt")
        expect(agent.tools.length).to eq(2)
      end

      it "overwrites existing custom tools" do
        existing_tool.update!(name: "Old Browser", description: "Old description")

        importer = described_class.new(json: export_json)
        expect { importer.import!(overwrite: true) }.not_to change { AiTool.count }

        existing_tool.reload
        expect(existing_tool.name).to eq("Old Browser") # Name from export_json
      end

      it "prunes orphan secret bindings when contracts change on overwrite" do
        secret = Fabricate(:ai_secret, name: "old_cred")
        existing_tool.update!(
          secret_contracts: [{ "alias" => "old_key" }, { "alias" => "new_key" }],
        )
        existing_tool.replace_secret_bindings!(
          [
            { alias: "old_key", ai_secret_id: secret.id },
            { alias: "new_key", ai_secret_id: secret.id },
          ],
          created_by: Discourse.system_user,
        )
        expect(existing_tool.secret_bindings.count).to eq(2)

        # The export payload only declares "new_key" in contracts, so "old_key" binding should be pruned
        export_data = JSON.parse(export_json)
        export_data["custom_tools"].each do |tool_data|
          if tool_data["tool_name"] == "browse_web"
            tool_data["secret_contracts"] = [{ "alias" => "new_key" }]
          end
        end

        importer = described_class.new(json: export_data)
        importer.import!(overwrite: true)

        existing_tool.reload
        expect(existing_tool.secret_contracts).to eq([{ "alias" => "new_key" }])
        expect(existing_tool.secret_bindings.pluck(:alias)).to eq(["new_key"])
      end
    end

    context "when importing mcp server assignments" do
      fab!(:ai_mcp_server) { Fabricate(:ai_mcp_server, name: "Jira") }
      fab!(:ai_agent) { Fabricate(:ai_agent, tools: []) }

      let!(:export_json) do
        ai_agent.ai_mcp_servers << ai_mcp_server
        DiscourseAi::AgentExporter.new(agent: ai_agent).export
      end

      it "rebinds the imported agent to local mcp servers by name" do
        ai_agent.destroy

        importer = described_class.new(json: export_json)
        agent = importer.import!

        expect(agent.ai_mcp_servers.pluck(:name)).to eq(["Jira"])
      end

      it "restores selected MCP tool names" do
        ai_agent
          .ai_agent_mcp_servers
          .find_by!(ai_mcp_server_id: ai_mcp_server.id)
          .update!(selected_tool_names: ["search_issues"])
        DiscourseAi::Mcp::ToolRegistry
          .stubs(:tool_definitions_for)
          .with(ai_mcp_server)
          .returns(
            [
              { "name" => "search_issues", "description" => "Search", "inputSchema" => {} },
              { "name" => "create_issue", "description" => "Create", "inputSchema" => {} },
            ],
          )

        refreshed_export_json = DiscourseAi::AgentExporter.new(agent: ai_agent).export
        ai_agent.destroy

        importer = described_class.new(json: refreshed_export_json)
        agent = importer.import!

        expect(agent.ai_agent_mcp_servers.first.selected_tool_names).to eq(["search_issues"])
      end

      it "raises when imported selected MCP tools do not exist locally" do
        ai_agent
          .ai_agent_mcp_servers
          .find_by!(ai_mcp_server_id: ai_mcp_server.id)
          .update!(selected_tool_names: ["search_issues"])

        refreshed_export_json = DiscourseAi::AgentExporter.new(agent: ai_agent).export
        ai_agent.destroy

        DiscourseAi::Mcp::ToolRegistry
          .stubs(:tool_definitions_for)
          .with(ai_mcp_server)
          .returns([{ "name" => "create_issue", "description" => "Create", "inputSchema" => {} }])

        importer = described_class.new(json: refreshed_export_json)

        expect { importer.import! }.to raise_error(
          DiscourseAi::AgentImporter::ImportError,
        ) do |error|
          expect(error.message).to eq(
            I18n.t("discourse_ai.errors.mcp_server_tools_not_found", name: "Jira"),
          )
          expect(error.conflicts[:mcp_servers]).to eq(["Jira"])
        end
      end

      it "raises when the referenced mcp server is missing" do
        ai_mcp_server.destroy

        importer = described_class.new(json: export_json)

        expect { importer.import! }.to raise_error(
          DiscourseAi::AgentImporter::ImportError,
        ) { |error| expect(error.conflicts[:mcp_servers]).to eq(["Jira"]) }
      end
    end

    context "with legacy persona format" do
      let(:legacy_hash) do
        {
          "meta" => {
            "version" => "1.0",
          },
          "persona" => {
            "name" => "Legacy Agent",
            "description" => "A legacy persona",
            "system_prompt" => "You are a legacy assistant",
            "temperature" => 0.7,
            "top_p" => 0.9,
            "response_format" => [],
            "examples" => [],
            "tools" => ["SearchCommand"],
          },
          "custom_tools" => [],
        }
      end

      it "imports a legacy persona hash successfully" do
        importer = described_class.new(json: legacy_hash)
        agent = importer.import!

        expect(agent).to be_persisted
        expect(agent.name).to eq("Legacy Agent")
        expect(agent.description).to eq("A legacy persona")
      end

      it "imports a legacy persona JSON string successfully" do
        importer = described_class.new(json: legacy_hash.to_json)
        agent = importer.import!

        expect(agent).to be_persisted
        expect(agent.name).to eq("Legacy Agent")
      end

      it "detects conflicts with legacy format" do
        Fabricate(:ai_agent, name: "Legacy Agent")

        importer = described_class.new(json: legacy_hash)

        expect { importer.import! }.to raise_error(
          DiscourseAi::AgentImporter::ImportError,
        ) { |error| expect(error.conflicts[:agent]).to eq("Legacy Agent") }
      end

      it "overwrites with legacy format when overwrite: true" do
        existing = Fabricate(:ai_agent, name: "Legacy Agent", description: "Old")

        importer = described_class.new(json: legacy_hash)
        agent = importer.import!(overwrite: true)

        expect(agent.id).to eq(existing.id)
        expect(agent.description).to eq("A legacy persona")
      end
    end

    context "with invalid payload" do
      it "raises an error for invalid JSON structure" do
        expect { described_class.new(json: "{}").import! }.to raise_error(
          ArgumentError,
          "Invalid agent export data",
        )
      end

      it "raises an error for missing agent data" do
        expect { described_class.new(json: { "custom_tools" => [] }).import! }.to raise_error(
          ArgumentError,
          "Invalid agent export data",
        )
      end
    end
  end
end
