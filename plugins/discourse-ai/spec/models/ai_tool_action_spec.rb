# frozen_string_literal: true

RSpec.describe AiToolAction do
  fab!(:ai_agent)

  before { enable_current_plugin }

  it "validates presence of tool_name" do
    action = AiToolAction.new(bot_user_id: -1, ai_agent: ai_agent)
    expect(action).not_to be_valid
    expect(action.errors[:tool_name]).to be_present
  end

  it "validates presence of bot_user_id" do
    action = AiToolAction.new(tool_name: "close_topic", ai_agent: ai_agent)
    expect(action).not_to be_valid
    expect(action.errors[:bot_user_id]).to be_present
  end

  it "creates a valid record" do
    action =
      AiToolAction.create!(
        tool_name: "close_topic",
        tool_parameters: {
          topic_id: 1,
          closed: true,
          reason: "test",
        },
        ai_agent: ai_agent,
        bot_user_id: -1,
      )

    expect(action).to be_persisted
    expect(action.tool_name).to eq("close_topic")
    expect(action.tool_parameters).to eq("topic_id" => 1, "closed" => true, "reason" => "test")
  end
end
