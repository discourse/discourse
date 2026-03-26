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

  describe "RESERVED_EXTERNAL_AGENT_IDS" do
    it "includes data_explorer_query_generator" do
      expect(described_class::RESERVED_EXTERNAL_AGENT_IDS[:data_explorer_query_generator]).to eq(
        -501,
      )
    end
  end
end
