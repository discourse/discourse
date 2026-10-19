# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Ai::Tools::WorkflowNodeCatalog do
  fab!(:admin)

  def invoke_tool(types)
    described_class.new(
      { types: types },
      bot_user: Discourse.system_user,
      llm: nil,
      context: DiscourseAi::Agents::BotContext.new(messages: [], user: admin),
    ).invoke
  end

  before { SiteSetting.discourse_ai_enabled = true }

  let(:result) do
    {
      nodes:
        contract_types
          .each_slice(described_class::MAX_TYPES)
          .flat_map { |types| invoke_tool(types)[:nodes] },
    }
  end
  let(:contract_types) do
    %w[
      trigger:topic_created
      trigger:post_created
      trigger:post_edited
      trigger:topic_closed
      trigger:tag_created
      trigger:user_added_to_group
      trigger:user_removed_from_group
      trigger:chat_message_created
      action:topic
      action:topic_tags
      action:tag_group
      action:post
      action:user
      action:send_personal_message
      action:group
      action:ai_agent
      flow:wait
    ]
  end
  let(:nodes_by_type) { result[:nodes].index_by { |node| node[:type] } }
  let(:output_contracts_by_type) do
    nodes_by_type.transform_values { |node| node.fetch(:output_contracts).first }.compact
  end
  let(:output_fields_by_type) do
    output_contracts_by_type.transform_values { |contract| contract.fetch(:fields) }
  end

  it "returns only the requested types and reports unknown ones", :aggregate_failures do
    result = invoke_tool(%w[action:code action:does_not_exist])

    expect(result[:nodes].map { |node| node[:type] }).to eq(["action:code"])
    expect(result[:unknown_types]).to eq(["action:does_not_exist"])
  end

  it "marks when requested types are cut off" do
    types = Array.new(described_class::MAX_TYPES + 2) { |index| "action:missing_#{index}" }

    expect(invoke_tool(types)[:truncated]).to eq(
      "Only the first #{described_class::MAX_TYPES} of #{types.length} requested types are included.",
    )
  end

  it "treats nodes hidden from the palette as unknown" do
    hidden_node_type = DiscourseWorkflows::Nodes::LoopOverItems::V1.identifier

    expect(invoke_tool([hidden_node_type])).to include(nodes: [], unknown_types: [hidden_node_type])
  end

  it "includes Code node runtime notes" do
    code_node = invoke_tool(["action:code"])[:nodes].first

    expect(code_node[:notes]).to include(
      a_string_including("runOnceForEachItem must return one object"),
    )
  end

  it "exposes post author, topic link, and action output fields", :aggregate_failures do
    expect(output_fields_by_type.fetch("trigger:topic_created")).to include(
      "post.user_id" => "integer",
      "post.username" => "string",
      "post.post_number" => "integer",
      "post.topic_id" => "integer",
      "post.post_url" => "string",
      "post.upload_ids" => "array<integer>",
    )
    expect(output_fields_by_type.fetch("trigger:topic_created")).not_to include(
      "post.trust_level",
      "user.trust_level",
    )
    expect(output_fields_by_type.fetch("trigger:post_created")).to include(
      "post.user_id" => "integer",
      "post.username" => "string",
      "post.post_number" => "integer",
      "post.topic_id" => "integer",
      "post.post_url" => "string",
      "user.id" => "integer",
      "user.username" => "string",
      "user.trust_level" => "integer",
      "user.trust_level_name" => "string",
      "user.admin" => "boolean",
      "user.moderator" => "boolean",
      "user.staff" => "boolean",
    )
    expect(output_fields_by_type.fetch("trigger:post_created")).not_to include(
      "post.trust_level",
      "post.admin",
      "post.moderator",
      "post.staff",
    )
    expect(output_fields_by_type.fetch("trigger:post_edited")).to include(
      "post.id" => "integer",
      "post.raw" => "string",
      "user.trust_level" => "integer",
      "user.trust_level_name" => "string",
    )
    expect(output_fields_by_type.fetch("trigger:topic_closed")).to include(
      "topic.id" => "integer",
      "topic.title" => "string",
      "topic.slug" => "string",
      "topic.closed" => "boolean",
      "topic.archived" => "boolean",
    )
    expect(output_fields_by_type.fetch("trigger:tag_created")).to include(
      "tag.id" => "integer",
      "tag.name" => "string",
      "tag.slug" => "string",
      "tag.topic_count" => "integer",
      "tag.staff" => "boolean",
      "tag.description" => "string|null",
      "tag.description_cooked" => "string|null",
    )
    {
      "trigger:user_added_to_group" => "\"added\"",
      "trigger:user_removed_from_group" => "\"removed\"",
    }.each do |trigger_type, membership_action|
      expect(output_fields_by_type.fetch(trigger_type)).to include(
        "user.id" => "integer",
        "user.username" => "string",
        "user.trust_level" => "integer",
        "group.id" => "integer",
        "group.name" => "string",
        "group.full_name" => "string|null",
        "group.automatic" => "boolean",
        "membership.action" => membership_action,
        "membership.automatic" => "boolean|null",
      )
    end
    expect(output_fields_by_type.fetch("action:topic")).to include(
      "topic.id" => "integer",
      "topic.slug" => "string",
      "topic.archived" => "boolean",
      "post.post_url" => "string",
    )
    expect(output_fields_by_type.fetch("action:topic")).not_to include(
      "post.trust_level",
      "post.upload_ids",
    )
    expect(output_fields_by_type.fetch("action:topic_tags")).to include(
      "topic_id" => "integer",
      "tag_names" => "array<string>",
    )
    expect(output_fields_by_type.fetch("action:tag_group")).to include(
      "tag_group_id" => "integer",
      "tag_group_name" => "string",
      "tag_names" => "array<string>",
    )
    expect(output_fields_by_type.fetch("action:post")).to include(
      "post.id" => "integer",
      "post.topic_id" => "integer",
      "post.post_url" => "string",
    )
    expect(output_fields_by_type.fetch("action:user")).to include(
      "user.id" => "integer",
      "user.username" => "string",
      "user.bio_raw" => "string|null",
      "user.title" => "string|null",
      "user.manual_locked_trust_level" => "integer|null",
      "user.trust_level_locked" => "boolean",
      "user.user_fields" => "object",
      "user.groups" => "array<object>",
      "user.groups[0].name" => "string",
    )
    expect(output_fields_by_type.fetch("action:send_personal_message")).to include(
      "topic.id" => "integer",
      "topic.slug" => "string",
      "post.id" => "integer",
      "post.post_url" => "string",
    )
    expect(output_contracts_by_type.fetch("action:group")[:variants]).to include(
      a_hash_including(
        mode: "replace",
        display_options: {
          "show" => {
            "operation" => %w[add remove],
          },
        },
        fields:
          a_hash_including(
            "group.id" => "integer",
            "group.name" => "string",
            "user.username" => "string",
          ),
      ),
      a_hash_including(
        mode: "replace",
        display_options: {
          "show" => {
            "operation" => ["get"],
          },
        },
        fields: a_hash_including("group.id" => "integer", "group.user_count" => "integer"),
      ),
      a_hash_including(
        mode: "merge",
        display_options: {
          "show" => {
            "operation" => ["check_membership"],
          },
        },
        fields: a_hash_including("group_membership.in_group" => "boolean"),
      ),
    )
    expect(output_contracts_by_type.fetch("flow:wait")[:variants]).to include(
      a_hash_including(
        mode: "replace",
        display_options: {
          "show" => {
            "resume" => ["webhook"],
          },
        },
        fields: a_hash_including("method" => "string", "body" => "unknown"),
      ),
    )
    expect(output_fields_by_type.fetch("trigger:chat_message_created")).to include(
      "message.id" => "integer",
      "channel.id" => "integer",
      "user.id" => "integer",
      "user.username" => "string",
      "user.avatar_template" => "string",
    )
    expect(output_fields_by_type.fetch("trigger:chat_message_created")).not_to include(
      "user.trust_level",
      "user.admin",
      "user.moderator",
      "user.staff",
    )
    expect(output_fields_by_type.fetch("action:ai_agent")).to include("result" => "string")
  end

  it "includes declarative filter and topic lookup examples", :aggregate_failures do
    result =
      invoke_tool(
        %w[
          condition:filter
          condition:if
          action:group
          action:user
          action:topic
          action:post
          action:send_personal_message
        ],
      )
    filter_node = result[:nodes].find { |node| node[:type] == "condition:filter" }
    group_node = result[:nodes].find { |node| node[:type] == "action:group" }
    user_node = result[:nodes].find { |node| node[:type] == "action:user" }
    topic_node = result[:nodes].find { |node| node[:type] == "action:topic" }
    post_node = result[:nodes].find { |node| node[:type] == "action:post" }
    personal_message_node =
      result[:nodes].find { |node| node[:type] == "action:send_personal_message" }
    if_node = result[:nodes].find { |node| node[:type] == "condition:if" }
    cake_example =
      filter_node[:examples].find { |example| example[:name] == "Keep TL1 posts mentioning cake" }
    trust_level_example =
      filter_node[:examples].find { |example| example[:name] == "Keep TL1-or-lower post authors" }

    expect(cake_example[:parameters]).to include(combinator: "and")
    expect(cake_example.dig(:parameters, :conditions)).to contain_exactly(
      include(leftValue: "={{ $json.user.trust_level }}", rightValue: "1"),
      include(leftValue: "={{ $json.post.raw }}", rightValue: "cake"),
    )
    expect(trust_level_example.dig(:parameters, :conditions)).to contain_exactly(
      include(
        leftValue: "={{ $json.user.trust_level }}",
        rightValue: "1",
        operator: include(operation: "lte", type: "number"),
      ),
    )
    expect(topic_node[:examples]).to contain_exactly(
      include(parameters: include(operation: "get", topic_id: "={{ $json.topic.id }}")),
    )
    expect(post_node[:examples]).to contain_exactly(
      include(parameters: include(operation: "create", topic_id: "={{ $json.topic.id }}")),
      include(parameters: include(operation: "delete", post_id: "={{ $json.post.id }}")),
      include(parameters: include(operation: "recover", post_id: "={{ $json.post.id }}")),
    )
    expect(group_node[:examples]).to contain_exactly(
      include(
        parameters:
          include(
            operation: "check_membership",
            username: "={{ $json.user.username }}",
            group_id: 123,
          ),
      ),
    )
    expect(user_node[:examples]).to contain_exactly(
      include(parameters: include(operation: "get", username: "={{ $json.user.username }}")),
      include(
        parameters:
          include(
            operation: "edit",
            updates: include(title: "Member", trust_level: "2", trust_level_locked: true),
          ),
      ),
    )
    expect(personal_message_node[:examples]).to contain_exactly(
      include(
        parameters:
          include(
            recipient_usernames: ["admin"],
            raw: "=A group member posted: {{ $json.post.post_url }}",
          ),
      ),
    )
    expect(if_node[:examples].first.dig(:parameters, :conditions)).to contain_exactly(
      include(leftValue: "={{ $json.user.trust_level }}", rightValue: "1"),
    )
  end
end
