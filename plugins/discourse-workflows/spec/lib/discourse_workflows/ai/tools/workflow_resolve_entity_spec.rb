# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Ai::Tools::WorkflowResolveEntity do
  fab!(:admin)

  it "resolves categories by name" do
    category = Fabricate(:category, name: "Bug Reports", slug: "bugs")
    context = DiscourseAi::Agents::BotContext.new(messages: [], user: admin)
    result =
      described_class.new(
        { kind: "category", query: "bug" },
        bot_user: Discourse.system_user,
        llm: nil,
        context: context,
      ).invoke

    expect(result).to eq(
      status: "success",
      kind: "category",
      matches: [{ id: category.id, name: category.name, slug: category.slug }],
    )
  end
end
