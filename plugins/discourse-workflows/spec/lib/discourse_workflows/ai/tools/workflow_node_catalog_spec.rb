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

  it "exposes post author, topic link, and action output fields", :aggregate_failures do
    result = invoke_tool
    nodes_by_type = result[:nodes].index_by { |node| node[:type] }

    expect(result[:status]).to eq("success")
    expect(nodes_by_type.dig("trigger:topic_created", :output_schema)).to include(
      "post.user_id" => "integer",
      "post.username" => "string",
      "post.post_number" => "integer",
      "post.topic_id" => "integer",
      "post.post_url" => "string",
      "post.upload_ids" => "array<integer>",
    )
    expect(nodes_by_type.dig("trigger:topic_created", :output_schema)).not_to include(
      "post.trust_level",
      "user.trust_level",
    )
    expect(nodes_by_type.dig("trigger:post_created", :output_schema)).to include(
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
    expect(nodes_by_type.dig("trigger:post_created", :output_schema)).not_to include(
      "post.trust_level",
      "post.admin",
      "post.moderator",
      "post.staff",
    )
    expect(nodes_by_type.dig("trigger:post_edited", :output_schema)).to include(
      "post.id" => "integer",
      "post.raw" => "string",
      "user.trust_level" => "integer",
      "user.trust_level_name" => "string",
    )
    expect(nodes_by_type.dig("trigger:topic_closed", :output_schema)).to include(
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
      expect(nodes_by_type.dig(trigger_type, :output_schema)).to include(
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
    expect(nodes_by_type.dig("action:topic", :output_schema)).to include(
      "topic.id" => "integer",
      "topic.slug" => "string",
      "topic.archived" => "boolean",
      "post.post_url" => "string",
    )
    expect(nodes_by_type.dig("action:topic", :output_schema)).not_to include(
      "post.trust_level",
      "post.upload_ids",
    )
    expect(nodes_by_type.dig("action:topic_tags", :output_schema)).to include(
      "topic_id" => "integer",
      "tag_names" => "array<string>",
    )
    expect(nodes_by_type.dig("action:post", :output_schema)).to include(
      "post.id" => "integer",
      "post.topic_id" => "integer",
      "post.post_url" => "string",
    )
    expect(nodes_by_type.dig("action:user", :output_schema)).to include(
      "user.id" => "integer",
      "user.username" => "string",
      "user.bio_raw" => "string|null",
      "user.title" => "string|null",
      "user.manual_locked_trust_level" => "integer|null",
      "user.trust_level_locked" => "boolean",
      "user.user_fields" => "object",
      "user.groups" => "array<object>",
      "user.groups[].name" => "string",
    )
    expect(nodes_by_type.dig("action:send_personal_message", :output_schema)).to include(
      "topic.id" => "integer",
      "topic.slug" => "string",
      "post.id" => "integer",
      "post.post_url" => "string",
    )
    expect(nodes_by_type.dig("action:ai_agent", :output_schema)).to include("result" => "string")
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
