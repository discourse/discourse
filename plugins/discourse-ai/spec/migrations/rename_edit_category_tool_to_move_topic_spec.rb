# frozen_string_literal: true

require Rails.root.join(
          "plugins/discourse-ai/db/migrate/20260821210543_rename_edit_category_tool_to_move_topic.rb",
        )

RSpec.describe RenameEditCategoryToolToMoveTopic do
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

  it "renames EditCategory entries while preserving options and other tools" do
    DB.exec(
      "UPDATE ai_agents SET tools = :tools WHERE id = :id",
      tools: [["EditCategory", { "option" => "x" }, true], ["CloseTopic", nil, false]].to_json,
      id: agent.id,
    )

    described_class.new.up

    expect(stored_tools(agent.id)).to eq(
      [["MoveTopic", { "option" => "x" }, true], ["CloseTopic", nil, false]],
    )
  end

  it "renames bare string entries" do
    DB.exec(
      "UPDATE ai_agents SET tools = :tools WHERE id = :id",
      tools: %w[EditCategory CloseTopic].to_json,
      id: agent.id,
    )

    described_class.new.up

    expect(stored_tools(agent.id)).to eq(%w[MoveTopic CloseTopic])
  end

  it "leaves agents that already have MoveTopic untouched" do
    tools = [["EditCategory", nil, false], ["MoveTopic", nil, false]]
    DB.exec(
      "UPDATE ai_agents SET tools = :tools WHERE id = :id",
      tools: tools.to_json,
      id: agent.id,
    )

    described_class.new.up

    expect(stored_tools(agent.id)).to eq(tools)
  end
end
