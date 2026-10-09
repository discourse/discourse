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

  it "resolves tag groups by name" do
    tag_group = Fabricate(:tag_group, name: "Customer lifecycle")
    Fabricate(:tag_group, name: "Unrelated")
    context = DiscourseAi::Agents::BotContext.new(messages: [], user: admin)
    result =
      described_class.new(
        { kind: "tag_group", query: "lifecycle" },
        bot_user: Discourse.system_user,
        llm: nil,
        context: context,
      ).invoke

    expect(result).to eq(
      status: "success",
      kind: "tag_group",
      matches: [{ id: tag_group.id, name: tag_group.name }],
    )
  end
end
