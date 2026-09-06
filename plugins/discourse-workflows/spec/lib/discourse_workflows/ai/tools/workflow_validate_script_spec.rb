# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Ai::Tools::WorkflowValidateScript do
  fab!(:admin)

  def invoke_tool(parameters)
    context = DiscourseAi::Agents::BotContext.new(messages: [], user: admin)
    described_class.new(
      parameters,
      bot_user: Discourse.system_user,
      llm: nil,
      context: context,
    ).invoke
  end

  it "validates a run-once script and returns sample output" do
    result =
      invoke_tool(
        {
          mode: "runOnceForAllItems",
          code: "var items = $input.all(); items[0].json.added = true; return items;",
          sample_input_items: [{ "json" => { "id" => 1 } }],
        },
      )

    expect(result).to include(
      status: "success",
      valid: true,
      errors: [],
      sample_output_items: [{ "json" => { "id" => 1, "added" => true } }],
    )
  end

  it "rejects all-items access in per-item mode" do
    result =
      invoke_tool(
        {
          mode: "runOnceForEachItem",
          code: "var items = $input.all(); return { json: { count: items.length } };",
        },
      )

    expect(result).to include(
      status: "success",
      valid: false,
      errors: ["$input.all is only available in runOnceForAllItems mode"],
    )
  end

  it "rejects output that mixes reserved item keys with plain fields" do
    result =
      invoke_tool(
        { mode: "runOnceForAllItems", code: "return [{ json: { id: 1 }, extra: true }];" },
      )

    expect(result).to include(
      status: "success",
      valid: false,
      errors: ["Output item mixes reserved item keys with plain fields"],
    )
  end
end
