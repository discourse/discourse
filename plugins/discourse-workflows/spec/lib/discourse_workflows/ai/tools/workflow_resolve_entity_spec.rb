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

  it "resolves topics by title or id", :aggregate_failures do
    topic = Fabricate(:topic, title: "Can you solve a Rubik's cube?")
    Fabricate(:topic, title: "Unrelated topic")
    Fabricate(:private_message_topic, title: "Rubik's cube private chat")
    context = DiscourseAi::Agents::BotContext.new(messages: [], user: admin)
    resolve = ->(query) do
      described_class.new(
        { kind: "topic", query: },
        bot_user: Discourse.system_user,
        llm: nil,
        context:,
      ).invoke
    end

    expected = {
      status: "success",
      kind: "topic",
      matches: [{ id: topic.id, title: topic.title, slug: topic.slug }],
    }

    expect(resolve.("rubik")).to eq(expected)
    expect(resolve.(topic.id.to_s)).to eq(expected)
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
