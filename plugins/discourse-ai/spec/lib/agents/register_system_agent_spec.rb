# frozen_string_literal: true

describe DiscourseAi::Agents::Agent do
  describe ".register_system_agent" do
    let(:test_agent_class) { Class.new(described_class) }

    after do
      described_class.system_agents.delete(test_agent_class)
      described_class.instance_variable_set(:@system_agents_by_id, nil)
    end

    it "adds the agent to system_agents" do
      described_class.register_system_agent(test_agent_class, -999)
      expect(described_class.system_agents[test_agent_class]).to eq(-999)
    end

    it "busts the system_agents_by_id cache" do
      described_class.system_agents_by_id

      described_class.register_system_agent(test_agent_class, -999)

      expect(described_class.system_agents_by_id[-999]).to eq(test_agent_class)
    end
  end

  describe ".register_tool" do
    after { described_class.registered_tools.delete("TestTool") }

    it "makes the tool discoverable by name" do
      tool_klass = Class.new(DiscourseAi::Agents::Tools::Tool)
      described_class.register_tool("TestTool", tool_klass)
      expect(described_class.registered_tools["TestTool"]).to eq(tool_klass)
    end
  end

  describe "RESERVED_EXTERNAL_AGENT_IDS" do
    it "includes data_explorer_query_generator" do
      expect(described_class::RESERVED_EXTERNAL_AGENT_IDS[:data_explorer_query_generator]).to eq(
        -501,
      )
    end
  end
end
