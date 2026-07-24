# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::AdminDashboardHighlights do
  it "uses no tools and returns a structured highlight" do
    instance = described_class.new

    expect(instance.tools).to eq([])
    expect(instance.temperature).to eq(0)
    expect(instance.response_format).to eq([{ "key" => "highlight", "type" => "string" }])
  end

  it "is registered as a system agent with a deterministic id" do
    expect(DiscourseAi::Agents::Agent.system_agents[described_class]).to eq(-38)
    expect(SiteSetting.ai_admin_dashboard_highlights_agent).to eq("-38")
  end

  it "resolves records with its system id to the admin dashboard highlights class" do
    agent =
      AiAgent.find_by(id: -38) ||
        Fabricate(:ai_agent, id: -38, name: "Admin Dashboard Highlights #{SecureRandom.hex(4)}")
    agent.update!(allowed_group_ids: [Group::AUTO_GROUPS[:admins]])

    expect(agent.class_instance).to be < described_class
    expect(agent.allowed_group_ids).to contain_exactly(Group::AUTO_GROUPS[:admins])
  end
end
