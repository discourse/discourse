# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Ai::Tools::WorkflowNodeCatalog do
  fab!(:admin)

  before { SiteSetting.discourse_ai_enabled = true }

  def invoke_tool(query: nil, include_examples: false)
    context = DiscourseAi::Agents::BotContext.new(messages: [], user: admin)
    described_class.new(
      { query: query, include_examples: include_examples }.compact,
      bot_user: Discourse.system_user,
      llm: nil,
      context: context,
    ).invoke
  end

  def output_contract(nodes_by_type, type, output_index = 0)
    nodes_by_type.dig(type, :output_contracts, output_index)
  end

  def output_fields(nodes_by_type, type, output_index = 0)
    output_contract(nodes_by_type, type, output_index).fetch(:fields)
  end

  it "exposes post author, topic link, and action output fields", :aggregate_failures do
    result = invoke_tool
    nodes_by_type = result[:nodes].index_by { |node| node[:type] }

    expect(result[:status]).to eq("success")
    expect(output_fields(nodes_by_type, "trigger:topic_created")).to include(
      "post.user_id" => "integer",
      "post.username" => "string",
      "post.post_number" => "integer",
      "post.topic_id" => "integer",
      "post.post_url" => "string",
      "post.upload_ids" => "array<integer>",
    )
    expect(output_fields(nodes_by_type, "trigger:topic_created")).not_to include(
      "post.trust_level",
      "user.trust_level",
    )
    expect(output_fields(nodes_by_type, "trigger:post_created")).to include(
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
    expect(output_fields(nodes_by_type, "trigger:post_created")).not_to include(
      "post.trust_level",
      "post.admin",
      "post.moderator",
      "post.staff",
    )
    expect(output_fields(nodes_by_type, "trigger:post_edited")).to include(
      "post.id" => "integer",
      "post.raw" => "string",
      "user.trust_level" => "integer",
      "user.trust_level_name" => "string",
    )
    expect(output_fields(nodes_by_type, "trigger:topic_closed")).to include(
      "topic.id" => "integer",
      "topic.title" => "string",
      "topic.slug" => "string",
      "topic.closed" => "boolean",
      "topic.archived" => "boolean",
    )
    {
      "trigger:user_added_to_group" => "\"added\"",
      "trigger:user_removed_from_group" => "\"removed\"",
    }.each do |trigger_type, membership_action|
      expect(output_fields(nodes_by_type, trigger_type)).to include(
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
    expect(output_fields(nodes_by_type, "action:topic")).to include(
      "topic.id" => "integer",
      "topic.slug" => "string",
      "topic.archived" => "boolean",
      "post.post_url" => "string",
    )
    expect(output_fields(nodes_by_type, "action:topic")).not_to include(
      "post.trust_level",
      "post.upload_ids",
    )
    expect(output_fields(nodes_by_type, "action:topic_tags")).to include(
      "topic_id" => "integer",
      "tag_names" => "array<string>",
    )
    expect(output_fields(nodes_by_type, "action:post")).to include(
      "post.id" => "integer",
      "post.topic_id" => "integer",
      "post.post_url" => "string",
    )
    expect(output_fields(nodes_by_type, "action:user")).to include(
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
    expect(output_fields(nodes_by_type, "action:send_personal_message")).to include(
      "topic.id" => "integer",
      "topic.slug" => "string",
      "post.id" => "integer",
      "post.post_url" => "string",
    )
    expect(output_contract(nodes_by_type, "action:group")[:variants]).to include(
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
    expect(output_contract(nodes_by_type, "flow:wait")[:variants]).to include(
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
    expect(output_fields(nodes_by_type, "trigger:chat_message_created")).to include(
      "message.id" => "integer",
      "channel.id" => "integer",
      "user.id" => "integer",
      "user.username" => "string",
      "user.avatar_template" => "string",
    )
    expect(output_fields(nodes_by_type, "trigger:chat_message_created")).not_to include(
      "user.trust_level",
      "user.admin",
      "user.moderator",
      "user.staff",
    )
    expect(output_fields(nodes_by_type, "action:ai_agent")).to include("result" => "string")
  end

  it "matches broad multi-term catalog queries", :aggregate_failures do
    result =
      invoke_tool(
        query:
          "trigger topic_closed action topic get condition filter chat message dm group membership user profile trust title",
        include_examples: true,
      )
    node_types = result[:nodes].map { |node| node[:type] }

    expect(node_types).to include(
      "trigger:topic_closed",
      "action:topic",
      "condition:filter",
      "action:group",
      "action:user",
      "trigger:user_added_to_group",
      "trigger:user_removed_from_group",
      "action:send_chat_message",
      "action:send_personal_message",
    )
    expect(result[:nodes].find { |node| node[:type] == "action:topic" }[:examples]).to be_present
  end

  it "matches AI agent runner and attachment queries" do
    result = invoke_tool(query: "runner permissions attachments", include_examples: true)
    ai_agent_node = result[:nodes].find { |node| node[:type] == "action:ai_agent" }

    expect(ai_agent_node).to be_present
    expect(ai_agent_node.dig(:properties, "runner_username", "ui", "control")).to eq("actor")
    expect(ai_agent_node.dig(:examples, 0, :parameters)).to include(runner_username: "system")
  end

  it "includes declarative filter and topic lookup examples", :aggregate_failures do
    result = invoke_tool(include_examples: true)
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
