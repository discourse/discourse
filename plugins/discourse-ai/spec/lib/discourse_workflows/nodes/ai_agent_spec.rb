# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::AiAgent::V1 do
  fab!(:agent) { Fabricate(:ai_agent, name: "Workflow agent", enabled: true) }

  let(:bot) { instance_double(DiscourseAi::Agents::Bot) }
  let(:prompts) { [] }

  before do
    SiteSetting.discourse_ai_enabled = true

    allow(DiscourseAi::Agents::Bot).to receive(:as).and_return(bot)
    allow(bot).to receive(:reply) do |bot_context, &block|
      prompt = bot_context.messages.first[:content]

      prompts << prompt
      block.call("Reply to #{prompt}", nil, nil)
    end
  end

  describe ".load_options_context" do
    fab!(:disabled_agent) { Fabricate(:ai_agent, name: "Disabled agent", enabled: false) }
    fab!(:matching_agent) { Fabricate(:ai_agent, name: "Alpha agent", enabled: true) }
    fab!(:other_agent) { Fabricate(:ai_agent, name: "Gamma agent", enabled: true) }

    def load_options(filter: nil)
      context =
        DiscourseWorkflows::LoadOptionsContext.new(
          method_name: "agents",
          filter: filter,
          node_class: described_class,
        )

      described_class.load_options_context(context)
    end

    it "returns enabled AI agents for the chooser" do
      option_ids = [agent.id, disabled_agent.id]
      options = load_options.select { |option| option_ids.include?(option[:id]) }

      expect(options).to contain_exactly({ id: agent.id, name: agent.name })
    end

    it "filters AI agents by the filter term" do
      option_ids = [matching_agent.id, other_agent.id]
      options = load_options(filter: "alpha").select { |option| option_ids.include?(option[:id]) }

      expect(options).to contain_exactly({ id: matching_agent.id, name: matching_agent.name })
    end
  end

  it "runs the agent once per input item with item-specific parameters" do
    items =
      execute_node_output(
        configuration: {
          "agent_id" => agent.id,
          "prompt" => "={{ 'Prompt ' + $json.name }}",
        },
        input_items: [{ "json" => { "name" => "Ada" } }, { "json" => { "name" => "Grace" } }],
      ).first

    expect(prompts).to eq(["Prompt Ada", "Prompt Grace"])
    expect(items.map { |item| item["json"]["result"] }).to eq(
      ["Reply to Prompt Ada", "Reply to Prompt Grace"],
    )
    expect(items.map { |item| item["pairedItem"] }).to eq([{ "item" => 0 }, { "item" => 1 }])
    expect(bot).to have_received(:reply).twice
  end

  it "uses an empty string when the optional prompt is blank" do
    items = execute_node_output(configuration: { "agent_id" => agent.id }).first

    expect(prompts).to eq([""])
    expect(items.first["json"]["result"]).to eq("Reply to ")
  end
end
