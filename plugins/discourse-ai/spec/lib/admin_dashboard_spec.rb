# frozen_string_literal: true

RSpec.describe DiscourseAi::AdminDashboard do
  before do
    enable_current_plugin
    assign_fake_provider_to(:ai_default_llm_model)
    SiteSetting.ai_admin_dashboard_highlights_agent = "-38"
    AiAgent.where(id: -38).delete_all
  end

  it "reports whether admin dashboard AI is enabled" do
    SiteSetting.ai_admin_dashboard_enabled = false
    expect(described_class).not_to be_enabled

    SiteSetting.ai_admin_dashboard_enabled = true
    expect(described_class).to be_enabled
  end

  it "reports whether admin dashboard highlights are enabled" do
    SiteSetting.ai_admin_dashboard_enabled = true
    agent = Fabricate(:ai_agent, id: -38, enabled: true)

    expect(described_class).to be_highlights_enabled

    agent.update!(enabled: false)
    expect(described_class).not_to be_highlights_enabled
  end

  it "returns the selected admin dashboard highlights agent instance" do
    SiteSetting.ai_admin_dashboard_enabled = true
    Fabricate(:ai_agent, id: -38, enabled: true)

    expect(described_class.highlights_agent_id).to eq(-38)
    expect(described_class.highlights_agent_instance).to be_a(
      DiscourseAi::Agents::AdminDashboardHighlights,
    )
  end
end
