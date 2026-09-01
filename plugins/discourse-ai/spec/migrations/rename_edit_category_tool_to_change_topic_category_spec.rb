# frozen_string_literal: true

require Rails.root.join(
          "plugins/discourse-ai/db/migrate/20260821210543_rename_edit_category_tool_to_change_topic_category.rb",
        )

RSpec.describe RenameEditCategoryToolToChangeTopicCategory do
  fab!(:agent, :ai_agent)

  before { enable_current_plugin }

  around do |example|
    original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
    example.run
  ensure
    ActiveRecord::Migration.verbose = original_verbose
  end

  def stored_tools(id)
    value = DB.query_single("SELECT tools FROM ai_agents WHERE id = ?", id).first
    value.is_a?(String) ? JSON.parse(value) : value
  end

  it "renames EditCategory entries while preserving options and other tools" do
    DB.exec(
      "UPDATE ai_agents SET tools = :tools WHERE id = :id",
      tools: [["EditCategory", { "option" => "x" }, true], ["CloseTopic", nil, false]].to_json,
      id: agent.id,
    )

    described_class.new.up

    expect(stored_tools(agent.id)).to eq(
      [["ChangeTopicCategory", { "option" => "x" }, true], ["CloseTopic", nil, false]],
    )
  end

  it "renames bare string entries" do
    DB.exec(
      "UPDATE ai_agents SET tools = :tools WHERE id = :id",
      tools: %w[EditCategory CloseTopic].to_json,
      id: agent.id,
    )

    described_class.new.up

    expect(stored_tools(agent.id)).to eq(%w[ChangeTopicCategory CloseTopic])
  end

  it "renames pending tool approval actions so they stay replayable" do
    action_id =
      DB.query_single(
        "INSERT INTO ai_tool_actions (tool_name, tool_parameters, ai_agent_id, bot_user_id, created_at, updated_at)
         VALUES ('edit_category', '{}', :agent_id, -1, NOW(), NOW()) RETURNING id",
        agent_id: agent.id,
      ).first

    described_class.new.up

    expect(
      DB.query_single("SELECT tool_name FROM ai_tool_actions WHERE id = ?", action_id).first,
    ).to eq("change_topic_category")
  end

  it "leaves agents that already have ChangeTopicCategory untouched" do
    tools = [["EditCategory", nil, false], ["ChangeTopicCategory", nil, false]]
    DB.exec(
      "UPDATE ai_agents SET tools = :tools WHERE id = :id",
      tools: tools.to_json,
      id: agent.id,
    )

    described_class.new.up

    expect(stored_tools(agent.id)).to eq(tools)
  end
end
