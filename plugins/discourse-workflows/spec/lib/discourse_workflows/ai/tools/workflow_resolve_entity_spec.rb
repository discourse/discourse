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

  it "resolves options a node loads in the editor", :aggregate_failures do
    context = DiscourseAi::Agents::BotContext.new(messages: [], user: admin)
    resolve = ->(node_type) do
      described_class.new(
        { kind: "node_option", node_type:, method: "reviewable_types", query: "flagged post" },
        bot_user: Discourse.system_user,
        llm: nil,
        context:,
      ).invoke
    end

    expect(resolve.("trigger:reviewable_created")).to eq(
      status: "success",
      kind: "node_option",
      matches: [{ id: "ReviewableFlaggedPost", name: "Reviewable flagged post" }],
    )
    expect(resolve.("trigger:unknown")[:matches]).to eq([])
  end

  it "passes the node's other settings to options that depend on them" do
    node_class =
      Class.new(DiscourseWorkflows::NodeType) do
        description(name: "action:resolve_entity_parameters_test", version: "1.0")

        def self.load_options_context(context)
          [{ id: context.get_current_node_parameter("scope"), name: "Scoped option" }]
        end
      end
    (@registered_workflow_nodes ||= []) << node_class
    DiscourseWorkflows.register_node(node_class, Plugin::Instance.new)
    DiscourseWorkflows::Registry.reset_indexes!
    context = DiscourseAi::Agents::BotContext.new(messages: [], user: admin)
    result =
      described_class.new(
        {
          kind: "node_option",
          node_type: "action:resolve_entity_parameters_test",
          method: "options",
          query: "scoped",
          node_parameters: {
            scope: "posts",
          },
        },
        bot_user: Discourse.system_user,
        llm: nil,
        context:,
      ).invoke

    expect(result[:matches]).to eq([{ id: "posts", name: "Scoped option" }])
  end

  it "resolves no node options when the loader needs credentials" do
    node_class =
      Class.new(DiscourseWorkflows::NodeType) do
        description(name: "action:resolve_entity_credentials_test", version: "1.0")

        def self.load_options_context(context)
          context.get_credentials("api")
        end
      end
    (@registered_workflow_nodes ||= []) << node_class
    DiscourseWorkflows.register_node(node_class, Plugin::Instance.new)
    DiscourseWorkflows::Registry.reset_indexes!
    context = DiscourseAi::Agents::BotContext.new(messages: [], user: admin)
    result =
      described_class.new(
        {
          kind: "node_option",
          node_type: "action:resolve_entity_credentials_test",
          method: "channels",
          query: "general",
        },
        bot_user: Discourse.system_user,
        llm: nil,
        context:,
      ).invoke

    expect(result).to eq(status: "success", kind: "node_option", matches: [])
  end
end
