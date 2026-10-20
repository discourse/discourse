# frozen_string_literal: true

RSpec.describe DiscourseDataExplorer::AdminAssistant::Capability do
  fab!(:admin)

  before do
    SiteSetting.discourse_ai_enabled = true
    SiteSetting.data_explorer_enabled = true
    SiteSetting.data_explorer_ai_queries_enabled = true
  end

  it "reports disabled public settings without relying on an external policy" do
    SiteSetting.data_explorer_enabled = false
    expect(described_class.status(user: admin, phase: :visibility)).to eq(:disabled)
  end

  it "reports an unusable model configuration" do
    AiAgent.stubs(:find_by).returns(nil)
    expect(described_class.status(user: admin, phase: :visibility)).to eq(:unconfigured)
  end

  it "stops before model lookup when a generic policy denies access" do
    DiscourseAi::Agents::AdminAssistantAccess.stubs(:check).returns(
      DiscourseAi::Agents::AdminAssistantAccess::Result.new(allowed: false, message: "No"),
    )
    AiAgent.expects(:find_by).never

    expect(described_class.status(user: admin, phase: :generation)).to eq(:restricted)
    expect(described_class.message(user: admin, phase: :generation)).to eq("No")
  end
end
