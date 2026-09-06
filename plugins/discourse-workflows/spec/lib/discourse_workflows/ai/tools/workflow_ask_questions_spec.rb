# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Ai::Tools::WorkflowAskQuestions do
  fab!(:admin)

  it "normalizes clarification questions and pauses the agent chain", :aggregate_failures do
    tool =
      described_class.new(
        {
          questions: [
            {
              id: "trigger_scope",
              question: "Which topics should trigger this workflow?",
              multi_select: true,
              options: [
                { label: "All topics", description: "Run for every topic." },
                { label: "Support only", description: "Run only in support categories." },
              ],
            },
          ],
        },
        bot_user: Discourse.system_user,
        llm: nil,
        context: DiscourseAi::Agents::BotContext.new(messages: [], user: admin),
      )

    expect(tool.invoke).to eq(
      status: "waiting_for_user",
      questions: [
        {
          id: "trigger_scope",
          question: "Which topics should trigger this workflow?",
          multi_select: true,
          custom_allowed: true,
          options: [
            { label: "All topics", description: "Run for every topic." },
            { label: "Support only", description: "Run only in support categories." },
          ],
        },
      ],
    )
    expect(tool.chain_next_response?).to eq(false)
  end
end
