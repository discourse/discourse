# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Ai::Tools::WorkflowAuthoringResult do
  fab!(:admin)

  it "normalizes a proposed patch result and pauses the chain", :aggregate_failures do
    tool =
      described_class.new(
        {
          status: "proposed_patch",
          message: "Create a manual workflow",
          proposal: {
            title: "Manual workflow",
            summary: "Start with a manual trigger.",
            risk_level: "low",
            operations: [
              {
                op: "add_node",
                client_id: "manual-trigger",
                node: {
                  type: "trigger:manual",
                  name: "Manual trigger",
                },
              },
            ],
          },
        },
        bot_user: Discourse.system_user,
        llm: nil,
        context: DiscourseAi::Agents::BotContext.new(messages: [], user: admin),
      )

    expect(tool.invoke).to eq(
      status: "proposed_patch",
      message: "Create a manual workflow",
      questions: [],
      proposal: {
        "title" => "Manual workflow",
        "summary" => "Start with a manual trigger.",
        "risk_level" => "low",
        "operations" => [
          {
            "op" => "add_node",
            "client_id" => "manual-trigger",
            "node" => {
              "type" => "trigger:manual",
              "name" => "Manual trigger",
            },
          },
        ],
      },
    )
    expect(tool.chain_next_response?).to eq(false)
  end

  it "normalizes clarification questions" do
    tool =
      described_class.new(
        {
          status: "needs_clarification",
          message: "Choose a category.",
          questions: [
            {
              question: "Which category should trigger this workflow?",
              options: [
                { label: "Support", description: "Only support topics." },
                { label: "All", description: "All topics." },
              ],
            },
          ],
        },
        bot_user: Discourse.system_user,
        llm: nil,
        context: DiscourseAi::Agents::BotContext.new(messages: [], user: admin),
      )

    expect(tool.invoke[:questions]).to eq(
      [
        {
          id: "question_1",
          question: "Which category should trigger this workflow?",
          multi_select: false,
          custom_allowed: true,
          options: [
            { label: "Support", description: "Only support topics." },
            { label: "All", description: "All topics." },
          ],
        },
      ],
    )
  end

  it "returns an error for invalid proposed patches" do
    tool =
      described_class.new(
        { status: "proposed_patch", message: "Missing operations", proposal: {} },
        bot_user: Discourse.system_user,
        llm: nil,
        context: DiscourseAi::Agents::BotContext.new(messages: [], user: admin),
      )

    expect(tool.invoke).to eq(
      status: "error",
      message: "Proposed patch results must include proposal.operations",
      questions: [],
      proposal: {
      },
    )
  end
end
