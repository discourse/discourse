# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Ai::Tools::WorkflowValidatePatch do
  fab!(:admin)

  def invoke_tool(operations)
    context = DiscourseAi::Agents::BotContext.new(messages: [], user: admin)
    described_class.new(
      { operations: operations },
      bot_user: Discourse.system_user,
      llm: nil,
      context: context,
    ).invoke
  end

  it "returns inferred schemas for a dry-run graph", :aggregate_failures do
    operations = [
      {
        op: "add_node",
        client_id: "post-created",
        node: {
          type: "trigger:post_created",
          typeVersion: "1.0",
          name: "When post is created",
          position: {
            x: 0,
            y: 0,
          },
          parameters: {
          },
          credentials: {
          },
        },
      },
      {
        op: "add_node",
        client_id: "filter-posts",
        node: {
          type: "condition:filter",
          typeVersion: "1.0",
          name: "Filter TL1 cake posts",
          position: {
            x: 280,
            y: 0,
          },
          parameters: {
            combinator: "and",
            conditions: [],
          },
          credentials: {
          },
        },
      },
      {
        op: "add_connection",
        from: "post-created",
        to: "filter-posts",
        output_index: 0,
        input_index: 0,
        connection_type: "main",
      },
    ]

    result = invoke_tool(operations.map(&:to_json))
    schemas_by_name = result[:node_schemas].index_by { |schema| schema[:node_name] }

    expect(result).to include(status: "success", valid: true, errors: [])
    expect(schemas_by_name.dig("When post is created", :output_schema)).to include(
      "$json.user.trust_level" => "integer",
      "$json.user.trust_level_name" => "string",
      "$json.post.raw" => "string",
      "$json.post.post_url" => "string",
    )
    expect(schemas_by_name.dig("When post is created", :output_schema)).not_to include(
      "$json.post.trust_level",
    )
    expect(schemas_by_name.dig("Filter TL1 cake posts", :input_schema)).to include(
      "$json.user.trust_level" => "integer",
      "$json.post.raw" => "string",
      "$json.post.post_url" => "string",
    )
    expect(schemas_by_name.dig("Filter TL1 cake posts", :output_schema)).to include(
      "$json.user.trust_level" => "integer",
      "$json.post.raw" => "string",
      "$json.post.post_url" => "string",
    )
  end

  it "validates proposed AI agents and agent output schemas", :aggregate_failures do
    operations = [
      {
        op: "create_ai_agent",
        client_id: "sentiment-agent",
        agent: {
          name: "Workflow sentiment agent",
          description: "Determines whether a post needs follow up.",
          system_prompt: "Return positive, neutral, or negative for each Discourse post.",
        },
      },
      {
        op: "add_node",
        client_id: "post-created",
        node: {
          type: "trigger:post_created",
          typeVersion: "1.0",
          name: "Post created",
          position: {
            x: 0,
            y: 0,
          },
          parameters: {
          },
          credentials: {
          },
        },
      },
      {
        op: "add_node",
        client_id: "classify-post",
        node: {
          type: "action:ai_agent",
          typeVersion: "1.0",
          name: "Classify post",
          position: {
            x: 280,
            y: 0,
          },
          parameters: {
            agent_id: {
              "$ref" => "sentiment-agent",
            },
            prompt: "=Classify this post: {{ $json.post.raw }}",
          },
          credentials: {
          },
        },
      },
      {
        op: "add_node",
        client_id: "write-log",
        node: {
          type: "action:log",
          typeVersion: "1.0",
          name: "Log classification",
          position: {
            x: 560,
            y: 0,
          },
          parameters: {
            entries: {
              values: [{ key: "classification", value: "={{ $json.result }}" }],
            },
          },
          credentials: {
          },
        },
      },
      {
        op: "add_connection",
        from: "post-created",
        to: "classify-post",
        output_index: 0,
        input_index: 0,
        connection_type: "main",
      },
      {
        op: "add_connection",
        from: "classify-post",
        to: "write-log",
        output_index: 0,
        input_index: 0,
        connection_type: "main",
      },
    ]

    result = invoke_tool(operations)
    schemas_by_name = result[:node_schemas].index_by { |schema| schema[:node_name] }

    expect(result).to include(status: "success", valid: true, errors: [])
    expect(result[:created_resources]).to contain_exactly(
      include(
        "type" => "ai_agent",
        "client_id" => "sentiment-agent",
        "name" => "Workflow sentiment agent",
      ),
    )
    expect(schemas_by_name.dig("Classify post", :output_schema)).to include(
      "$json.result" => "string",
    )
    expect(schemas_by_name.dig("Log classification", :input_schema)).to include(
      "$json.result" => "string",
    )
  end

  it "passes schemas through group checks into private messages", :aggregate_failures do
    operations = [
      {
        op: "add_node",
        client_id: "post-created",
        node: {
          type: "trigger:post_created",
          typeVersion: "1.0",
          name: "Post created",
          position: {
            x: 0,
            y: 0,
          },
          parameters: {
          },
          credentials: {
          },
        },
      },
      {
        op: "add_node",
        client_id: "group-membership",
        node: {
          type: "action:group",
          typeVersion: "1.0",
          name: "Check friend group membership",
          position: {
            x: 280,
            y: 0,
          },
          parameters: {
            operation: "check_membership",
            username: "={{ $json.post.username }}",
            group_id: 1,
            actor_username: "system",
          },
          credentials: {
          },
        },
      },
      {
        op: "add_node",
        client_id: "friend-group",
        node: {
          type: "condition:if",
          typeVersion: "1.0",
          name: "Keep friend group posts",
          position: {
            x: 560,
            y: 0,
          },
          parameters: {
            combinator: "and",
            conditions: [
              {
                id: "member_of_friend_group",
                leftValue: "={{ $json.group_membership.in_group }}",
                operator: {
                  operation: "equals",
                  type: "boolean",
                  singleValue: false,
                },
                rightValue: true,
              },
            ],
          },
          credentials: {
          },
        },
      },
      {
        op: "add_node",
        client_id: "dm-admin",
        node: {
          type: "action:send_personal_message",
          typeVersion: "1.0",
          name: "DM admin",
          position: {
            x: 840,
            y: 0,
          },
          parameters: {
            recipient_usernames: ["admin"],
            title: "=New post from @{{ $json.post.username }}",
            raw: "=A friend group member posted: {{ $json.post.post_url }}",
            sender_username: "system",
          },
          credentials: {
          },
        },
      },
      {
        op: "add_connection",
        from: "post-created",
        to: "group-membership",
        output_index: 0,
        input_index: 0,
        connection_type: "main",
      },
      {
        op: "add_connection",
        from: "group-membership",
        to: "friend-group",
        output_index: 0,
        input_index: 0,
        connection_type: "main",
      },
      {
        op: "add_connection",
        from: "friend-group",
        to: "dm-admin",
        output_index: 0,
        input_index: 0,
        connection_type: "true",
      },
    ]

    result = invoke_tool(operations)
    schemas_by_name = result[:node_schemas].index_by { |schema| schema[:node_name] }

    expect(result).to include(status: "success", valid: true, errors: [])
    expect(schemas_by_name.dig("Keep friend group posts", :input_schema)).to include(
      "$json.post.username" => "string",
      "$json.post.post_url" => "string",
      "$json.group_membership.in_group" => "boolean",
    )
    expect(schemas_by_name.dig("DM admin", :input_schema)).to include(
      "$json.post.username" => "string",
      "$json.post.post_url" => "string",
    )
    expect(schemas_by_name.dig("DM admin", :output_schema)).to include(
      "$json.topic.id" => "integer",
      "$json.post.post_url" => "string",
    )
  end

  it "returns action output schemas and rejects unavailable downstream paths",
     :aggregate_failures do
    operations = [
      {
        op: "add_node",
        client_id: "topic-created",
        node: {
          type: "trigger:topic_created",
          typeVersion: "1.0",
          name: "Topic created",
          position: {
            x: 0,
            y: 0,
          },
          parameters: {
          },
          credentials: {
          },
        },
      },
      {
        op: "add_node",
        client_id: "add-tag",
        node: {
          type: "action:topic_tags",
          typeVersion: "1.0",
          name: "Add tag",
          position: {
            x: 280,
            y: 0,
          },
          parameters: {
            operation: "add",
            topic_id: "={{ $json.topic.id }}",
            tag_names: "needs-review",
            actor_username: "system",
          },
          credentials: {
          },
        },
      },
      {
        op: "add_node",
        client_id: "reply",
        node: {
          type: "action:post",
          typeVersion: "1.0",
          name: "Reply",
          position: {
            x: 560,
            y: 0,
          },
          parameters: {
            operation: "create",
            topic_id: "={{ $json.topic.id }}",
            raw: "Thanks for contacting support.",
            author_username: "system",
          },
          credentials: {
          },
        },
      },
      {
        op: "add_connection",
        from: "topic-created",
        to: "add-tag",
        output_index: 0,
        input_index: 0,
        connection_type: "main",
      },
      {
        op: "add_connection",
        from: "add-tag",
        to: "reply",
        output_index: 0,
        input_index: 0,
        connection_type: "main",
      },
    ]

    result = invoke_tool(operations)
    schemas_by_name = result[:node_schemas].index_by { |schema| schema[:node_name] }

    expect(result[:valid]).to eq(false)
    expect(result[:expression_errors]).to contain_exactly(
      a_string_including("Reply parameter topic_id references $json.topic.id"),
    )
    expect(schemas_by_name.dig("Add tag", :output_schema)).to include(
      "$json.topic_id" => "integer",
      "$json.tag_names" => "array<string>",
    )
    expect(schemas_by_name.dig("Reply", :input_schema)).to include(
      "$json.topic_id" => "integer",
      "$json.tag_names" => "array<string>",
    )
  end

  it "rejects condition builder keys that would not execute", :aggregate_failures do
    operations = [
      {
        op: "add_node",
        client_id: "post-created",
        node: {
          type: "trigger:post_created",
          typeVersion: "1.0",
          name: "Post created",
          position: {
            x: 0,
            y: 0,
          },
          parameters: {
          },
          credentials: {
          },
        },
      },
      {
        op: "add_node",
        client_id: "bad-condition",
        node: {
          type: "condition:if",
          typeVersion: "1.0",
          name: "Bad condition",
          position: {
            x: 260,
            y: 0,
          },
          parameters: {
            combinator: "and",
            conditions: [
              {
                left: "={{ $json.user.trust_level }}",
                operator: {
                  operation: "lte",
                  type: "number",
                },
                right: 1,
              },
            ],
          },
          credentials: {
          },
        },
      },
      {
        op: "add_connection",
        from: "post-created",
        to: "bad-condition",
        output_index: 0,
        input_index: 0,
        connection_type: "main",
      },
    ]

    result = invoke_tool(operations)

    expect(result[:valid]).to eq(false)
    expect(result[:expression_errors]).to contain_exactly(
      "Bad condition condition 1 must set leftValue. Use leftValue instead of left.",
      "Bad condition condition 1 must set rightValue for lte comparisons. Use rightValue instead of right.",
    )
  end

  it "rejects object-shaped condition values from AI drafts", :aggregate_failures do
    operations = [
      {
        op: "add_node",
        client_id: "post-created",
        node: {
          type: "trigger:post_created",
          typeVersion: "1.0",
          name: "Post created",
          position: {
            x: 0,
            y: 0,
          },
          parameters: {
          },
          credentials: {
          },
        },
      },
      {
        op: "add_node",
        client_id: "bad-condition",
        node: {
          type: "condition:filter",
          typeVersion: "1.0",
          name: "Bad condition",
          position: {
            x: 260,
            y: 0,
          },
          parameters: {
            combinator: "and",
            conditions: [
              {
                leftValue: {
                  type: "number",
                  value: "user.trust_level",
                },
                operator: {
                  operation: "lte",
                  type: "number",
                },
                rightValue: {
                  type: "number",
                  value: 1,
                },
              },
            ],
          },
          credentials: {
          },
        },
      },
      {
        op: "add_connection",
        from: "post-created",
        to: "bad-condition",
        output_index: 0,
        input_index: 0,
        connection_type: "main",
      },
    ]

    result = invoke_tool(operations)

    expect(result[:valid]).to eq(false)
    expect(result[:expression_errors]).to contain_exactly(
      "Bad condition condition 1 leftValue must be a scalar or expression string, not an object.",
      "Bad condition condition 1 rightValue must be a scalar or expression string, not an object.",
    )
  end

  it "rejects invalid output connection types", :aggregate_failures do
    operations = [
      {
        op: "add_node",
        client_id: "post-created",
        node: {
          type: "trigger:post_created",
          typeVersion: "1.0",
          name: "Post created",
          position: {
            x: 0,
            y: 0,
          },
          parameters: {
          },
          credentials: {
          },
        },
      },
      {
        op: "add_node",
        client_id: "filter-posts",
        node: {
          type: "condition:filter",
          typeVersion: "1.0",
          name: "Filter posts",
          position: {
            x: 260,
            y: 0,
          },
          parameters: {
            combinator: "and",
            conditions: [],
          },
          credentials: {
          },
        },
      },
      {
        op: "add_node",
        client_id: "log",
        node: {
          type: "action:log",
          typeVersion: "1.0",
          name: "Log post",
          position: {
            x: 520,
            y: 0,
          },
          parameters: {
            entries: {
              values: [{ key: "message", value: "post matched" }],
            },
          },
          credentials: {
          },
        },
      },
      {
        op: "add_connection",
        from: "post-created",
        to: "filter-posts",
        output_index: 0,
        input_index: 0,
        connection_type: "main",
      },
      {
        op: "add_connection",
        from: "filter-posts",
        to: "log",
        output_index: 0,
        input_index: 0,
        connection_type: "main",
      },
    ]

    result = invoke_tool(operations)

    expect(result[:valid]).to eq(false)
    expect(result[:graph_errors]).to contain_exactly(
      'Filter posts output connection_type "main" is invalid for condition:filter. Use one of: true, false.',
    )
  end

  it "does not advertise unavailable first-post trust fields after topic lookups",
     :aggregate_failures do
    operations = [
      {
        op: "add_node",
        client_id: "closed",
        node: {
          type: "trigger:topic_closed",
          typeVersion: "1.0",
          name: "Topic closed",
          position: {
            x: 0,
            y: 0,
          },
          parameters: {
            category_id: 1,
          },
          credentials: {
          },
        },
      },
      {
        op: "add_node",
        client_id: "get-topic",
        node: {
          type: "action:topic",
          typeVersion: "1.0",
          name: "Get closed topic",
          position: {
            x: 260,
            y: 0,
          },
          parameters: {
            operation: "get",
            topic_id: "={{ $json.topic.id }}",
            actor_username: "system",
          },
          credentials: {
          },
        },
      },
      {
        op: "add_node",
        client_id: "filter-tl1",
        node: {
          type: "condition:filter",
          typeVersion: "1.0",
          name: "Keep known topic authors",
          position: {
            x: 520,
            y: 0,
          },
          parameters: {
            combinator: "and",
            conditions: [
              {
                id: "topic_author_user_id",
                leftValue: "={{ $json.post.user_id }}",
                operator: {
                  operation: "gt",
                  type: "number",
                  singleValue: false,
                },
                rightValue: "0",
              },
            ],
          },
          credentials: {
          },
        },
      },
      {
        op: "add_connection",
        from: "closed",
        to: "get-topic",
        output_index: 0,
        input_index: 0,
        connection_type: "main",
      },
      {
        op: "add_connection",
        from: "get-topic",
        to: "filter-tl1",
        output_index: 0,
        input_index: 0,
        connection_type: "main",
      },
    ]

    result = invoke_tool(operations)
    schemas_by_name = result[:node_schemas].index_by { |schema| schema[:node_name] }

    expect(result).to include(status: "success", valid: true, errors: [])
    expect(schemas_by_name.dig("Topic closed", :output_schema)).not_to include(
      "$json.post.trust_level",
    )
    expect(schemas_by_name.dig("Get closed topic", :output_schema)).to include(
      "$json.post.post_url" => "string",
      "$json.post.user_id" => "integer",
    )
    expect(schemas_by_name.dig("Get closed topic", :output_schema)).not_to include(
      "$json.post.trust_level",
    )
    expect(schemas_by_name.dig("Keep known topic authors", :input_schema)).to include(
      "$json.post.post_url" => "string",
      "$json.post.user_id" => "integer",
    )
  end

  it "validates topic-closed schemas and dynamic template prefixes", :aggregate_failures do
    operations = [
      {
        op: "add_node",
        client_id: "closed",
        node: {
          type: "trigger:topic_closed",
          typeVersion: "1.0",
          name: "Topic closed",
          position: {
            x: 0,
            y: 0,
          },
          parameters: {
          },
          credentials: {
          },
        },
      },
      {
        op: "add_node",
        client_id: "wait",
        node: {
          type: "flow:wait",
          typeVersion: "1.0",
          name: "Wait 30 days",
          position: {
            x: 280,
            y: 0,
          },
          parameters: {
            resume: "time_interval",
            wait_amount: 30,
            wait_unit: "days",
          },
          credentials: {
          },
        },
      },
      {
        op: "add_node",
        client_id: "archive",
        node: {
          type: "action:topic",
          typeVersion: "1.0",
          name: "Archive topic",
          position: {
            x: 560,
            y: 0,
          },
          parameters: {
            operation: "archive",
            topic_id: "={{ $json.topic.id }}",
            actor_username: "system",
          },
          credentials: {
          },
        },
      },
      {
        op: "add_node",
        client_id: "chat",
        node: {
          type: "action:send_chat_message",
          typeVersion: "1.0",
          name: "Notify chat",
          position: {
            x: 840,
            y: 0,
          },
          parameters: {
            channel_id: 2,
            message: "Topic archived: {{ $json.topic.title }} ({{ $json.post.post_url }})",
          },
          credentials: {
          },
        },
      },
      {
        op: "add_connection",
        from: "closed",
        to: "wait",
        output_index: 0,
        input_index: 0,
        connection_type: "main",
      },
      {
        op: "add_connection",
        from: "wait",
        to: "archive",
        output_index: 0,
        input_index: 0,
        connection_type: "main",
      },
      {
        op: "add_connection",
        from: "archive",
        to: "chat",
        output_index: 0,
        input_index: 0,
        connection_type: "main",
      },
    ]

    result = invoke_tool(operations)
    schemas_by_name = result[:node_schemas].index_by { |schema| schema[:node_name] }

    expect(result[:valid]).to eq(false)
    expect(result[:expression_errors]).to contain_exactly(
      a_string_including("Notify chat parameter message contains {{ }} expressions"),
    )
    expect(schemas_by_name.dig("Topic closed", :output_schema)).to include(
      "$json.topic.id" => "integer",
      "$json.topic.slug" => "string",
    )
    expect(schemas_by_name.dig("Notify chat", :input_schema)).to include(
      "$json.topic.id" => "integer",
      "$json.topic.slug" => "string",
    )
  end
end
