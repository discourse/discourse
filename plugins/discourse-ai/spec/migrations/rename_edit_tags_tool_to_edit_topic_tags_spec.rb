# frozen_string_literal: true

require Rails.root.join(
          "plugins/discourse-ai/db/migrate/20260821210913_rename_edit_tags_tool_to_edit_topic_tags.rb",
        )

RSpec.describe RenameEditTagsToolToEditTopicTags do
  fab!(:agent, :ai_agent)

  before do
    enable_current_plugin
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
  end

  after { ActiveRecord::Migration.verbose = @original_verbose }

  def stored_tools(id)
    value = DB.query_single("SELECT tools FROM ai_agents WHERE id = ?", id).first
    value.is_a?(String) ? JSON.parse(value) : value
  end

  it "renames EditTags entries while preserving options and other tools" do
    DB.exec(
      "UPDATE ai_agents SET tools = :tools WHERE id = :id",
      tools: [["EditTags", { "option" => "x" }, true], ["CloseTopic", nil, false]].to_json,
      id: agent.id,
    )

    described_class.new.up

    expect(stored_tools(agent.id)).to eq(
      [["EditTopicTags", { "option" => "x" }, true], ["CloseTopic", nil, false]],
    )
  end

  it "renames bare string entries" do
    DB.exec(
      "UPDATE ai_agents SET tools = :tools WHERE id = :id",
      tools: %w[EditTags CloseTopic].to_json,
      id: agent.id,
    )

    described_class.new.up

    expect(stored_tools(agent.id)).to eq(%w[EditTopicTags CloseTopic])
  end

  it "renames pending tool approval actions so they stay replayable" do
    action_id =
      DB.query_single(
        "INSERT INTO ai_tool_actions (tool_name, tool_parameters, ai_agent_id, bot_user_id, created_at, updated_at)
         VALUES ('edit_tags', '{}', :agent_id, -1, NOW(), NOW()) RETURNING id",
        agent_id: agent.id,
      ).first

    described_class.new.up

    expect(
      DB.query_single("SELECT tool_name FROM ai_tool_actions WHERE id = ?", action_id).first,
    ).to eq("edit_topic_tags")
  end

  it "leaves agents that already have EditTopicTags untouched" do
    tools = [["EditTags", nil, false], ["EditTopicTags", nil, false]]
    DB.exec(
      "UPDATE ai_agents SET tools = :tools WHERE id = :id",
      tools: tools.to_json,
      id: agent.id,
    )

    described_class.new.up

    expect(stored_tools(agent.id)).to eq(tools)
  end
end
