# frozen_string_literal: true

RSpec.describe Jobs::DiscourseWorkflows::AuthorWithAi do
  fab!(:admin)
  fab!(:ai_agent)

  before do
    SiteSetting.discourse_workflows_ai_authoring_enabled = true
    SiteSetting.discourse_workflows_workflow_authoring_agent = ai_agent.id
  end

  it "passes persisted messages to the AI bot with valid types" do
    session =
      Fabricate(
        :discourse_workflows_ai_authoring_session,
        user: admin,
        messages: [{ "type" => "user", "content" => "Create a workflow" }],
      )
    structured_output = double
    captured_messages = nil
    fake_bot = double

    allow(structured_output).to receive(:read_buffered_property).with(:status).and_return(
      "needs_clarification",
    )
    allow(structured_output).to receive(:read_buffered_property).with(:message).and_return(
      "Which category should trigger it?",
    )
    allow(structured_output).to receive(:read_buffered_property).with(:questions).and_return(
      ["Which category?"],
    )
    allow(structured_output).to receive(:read_buffered_property).with(:proposal).and_return({})
    allow(fake_bot).to receive(:reply) do |context, &block|
      captured_messages = context.messages
      block.call(structured_output, nil, :structured_output)
      []
    end
    allow(DiscourseAi::Agents::Bot).to receive(:as).and_return(fake_bot)

    described_class.new.execute(
      session_id: session.id,
      user_id: admin.id,
      generation_id: SecureRandom.hex,
    )

    expect(captured_messages).to eq([{ type: :user, content: "Create a workflow" }])
    expect(session.reload).to have_attributes(
      status: "needs_clarification",
      latest_response: include("message" => "Which category should trigger it?"),
    )
  end

  it "highlights trigger author trust-level fields in AI context", :aggregate_failures do
    session =
      Fabricate(
        :discourse_workflows_ai_authoring_session,
        user: admin,
        messages: [{ "type" => "user", "content" => "Create a TL1 post workflow" }],
      )
    structured_output = double
    captured_custom_instructions = nil
    fake_bot = double

    allow(structured_output).to receive(:read_buffered_property).with(:status).and_return(
      "explanation",
    )
    allow(structured_output).to receive(:read_buffered_property).with(:message).and_return(
      "No changes needed",
    )
    allow(structured_output).to receive(:read_buffered_property).with(:questions).and_return([])
    allow(structured_output).to receive(:read_buffered_property).with(:proposal).and_return({})
    allow(fake_bot).to receive(:reply) do |context, &block|
      captured_custom_instructions = context.custom_instructions
      block.call(structured_output, nil, :structured_output)
      []
    end
    allow(DiscourseAi::Agents::Bot).to receive(:as).and_return(fake_bot)

    described_class.new.execute(
      session_id: session.id,
      user_id: admin.id,
      generation_id: SecureRandom.hex,
    )

    expect(captured_custom_instructions).to include(
      "trigger:post_created exposes the created post author under post.*",
      "post.trust_level",
      "action:topic with operation get",
      "Full graph and node catalog are intentionally not preloaded",
      "Do not ask whether trust level is available",
    )
    payload_json = captured_custom_instructions.split("tools for details:\n", 2).last
    payload = JSON.parse(payload_json)
    expect(payload).not_to have_key("node_catalog")
    expect(payload).not_to have_key("workflow_graph")
    expect(payload.dig("context_tools", "workflow_node_catalog")).to include("node parameters")
    expect(payload.dig("context_tools", "workflow_graph_context")).to include("current graph")
    expect(payload["trigger_author_field_facts"]).to include(
      a_string_including("trigger:post_created"),
    )
  end

  it "parses raw JSON when structured output is empty" do
    session =
      Fabricate(
        :discourse_workflows_ai_authoring_session,
        user: admin,
        messages: [{ "type" => "user", "content" => "Create a workflow" }],
      )
    structured_output = double
    fake_bot = double
    json_response = {
      status: "needs_clarification",
      message: "Which category should trigger it?",
      questions: ["Which category?"],
      proposal: {
      },
    }.to_json

    allow(structured_output).to receive(:read_buffered_property).with(:status).and_return(nil)
    allow(structured_output).to receive(:read_buffered_property).with(:message).and_return(nil)
    allow(structured_output).to receive(:read_buffered_property).with(:questions).and_return(nil)
    allow(structured_output).to receive(:read_buffered_property).with(:proposal).and_return(nil)
    allow(fake_bot).to receive(:reply) do |_context, &block|
      block.call(structured_output, nil, :structured_output)
      [[json_response, "system"]]
    end
    allow(DiscourseAi::Agents::Bot).to receive(:as).and_return(fake_bot)

    described_class.new.execute(
      session_id: session.id,
      user_id: admin.id,
      generation_id: SecureRandom.hex,
    )

    expect(session.reload).to have_attributes(
      status: "needs_clarification",
      latest_response: include("message" => "Which category should trigger it?"),
    )
  end

  it "falls back when structured patches are incomplete", :aggregate_failures do
    workflow = Fabricate(:discourse_workflows_workflow, created_by: admin)
    session =
      Fabricate(
        :discourse_workflows_ai_authoring_session,
        user: admin,
        workflow: workflow,
        messages: [{ "type" => "user", "content" => "Create a manual workflow" }],
      )
    structured_output = double
    fake_bot = double
    json_response = {
      status: "proposed_patch",
      message: "Create a manual workflow",
      questions: [],
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
    }.to_json

    allow(structured_output).to receive(:read_buffered_property).with(:status).and_return(
      "proposed_patch",
    )
    allow(structured_output).to receive(:read_buffered_property).with(:message).and_return(
      "Create a manual workflow",
    )
    allow(structured_output).to receive(:read_buffered_property).with(:questions).and_return([])
    allow(structured_output).to receive(:read_buffered_property).with(:proposal).and_return({})
    allow(fake_bot).to receive(:reply) do |_context, &block|
      block.call(structured_output, nil, :structured_output)
      [[json_response, "system"]]
    end
    allow(DiscourseAi::Agents::Bot).to receive(:as).and_return(fake_bot)

    described_class.new.execute(
      session_id: session.id,
      user_id: admin.id,
      generation_id: SecureRandom.hex,
    )

    expect(session.reload).to have_attributes(status: "proposal_ready", risk_level: "low")
    expect(session.proposed_patch.dig("patch_validation", "valid")).to eq(true)
  end

  it "uses ask-questions tool calls when the agent needs clarification", :aggregate_failures do
    session =
      Fabricate(
        :discourse_workflows_ai_authoring_session,
        user: admin,
        latest_request: "Create a workflow",
        messages: [{ "type" => "user", "content" => "Create a workflow" }],
      )
    questions = [
      {
        id: "trigger_scope",
        question: "Which topics should trigger this workflow?",
        multi_select: false,
        custom_allowed: true,
        options: [
          { label: "All topics", description: "Run for every topic." },
          { label: "Support only", description: "Run only in support categories." },
        ],
      },
    ]
    raw_context = [
      [
        { arguments: { questions: questions } }.to_json,
        "tool-call-id",
        "tool_call",
        "workflow_ask_questions",
      ],
      [
        { status: "waiting_for_user", questions: questions }.to_json,
        "tool-call-id",
        "tool",
        "workflow_ask_questions",
      ],
    ]
    fake_bot = double

    allow(fake_bot).to receive(:reply).and_return(raw_context)
    allow(DiscourseAi::Agents::Bot).to receive(:as).and_return(fake_bot)

    described_class.new.execute(
      session_id: session.id,
      user_id: admin.id,
      generation_id: SecureRandom.hex,
    )

    expect(session.reload).to have_attributes(status: "needs_clarification", risk_level: nil)
    expect(session.latest_response).to include(
      "message" => I18n.t("discourse_workflows.ai.clarification_message"),
      "questions" => [JSON.parse(questions.first.to_json)],
    )
  end

  it "uses patch tool calls when final text is blank", :aggregate_failures do
    workflow = Fabricate(:discourse_workflows_workflow, created_by: admin)
    session =
      Fabricate(
        :discourse_workflows_ai_authoring_session,
        user: admin,
        workflow: workflow,
        latest_request: "Create a manual workflow",
        messages: [{ "type" => "user", "content" => "Create a manual workflow" }],
      )
    operations = [
      {
        op: "add_node",
        client_id: "manual-trigger",
        node: {
          type: "trigger:manual",
          name: "Manual trigger",
          credentials: [],
        },
      },
    ]
    raw_context = [
      [
        { arguments: { workflow_id: workflow.id, operations: operations.map(&:to_json) } }.to_json,
        "tool-call-id",
        "tool_call",
        "workflow_validate_patch",
      ],
      [
        { status: "success", valid: true }.to_json,
        "tool-call-id",
        "tool",
        "workflow_validate_patch",
      ],
    ]
    fake_bot = double

    allow(fake_bot).to receive(:reply).and_return(raw_context)
    allow(DiscourseAi::Agents::Bot).to receive(:as).and_return(fake_bot)

    described_class.new.execute(
      session_id: session.id,
      user_id: admin.id,
      generation_id: SecureRandom.hex,
    )

    expect(session.reload).to have_attributes(status: "proposal_ready", risk_level: "medium")
    expect(session.latest_response).to include(
      "message" => I18n.t("discourse_workflows.ai.tool_call_proposal_message"),
    )
    expect(session.proposed_patch.dig("patch_validation", "valid")).to eq(true)
  end

  it "parses fenced JSON proposals from raw context", :aggregate_failures do
    workflow = Fabricate(:discourse_workflows_workflow, created_by: admin)
    session =
      Fabricate(
        :discourse_workflows_ai_authoring_session,
        user: admin,
        workflow: workflow,
        messages: [{ "type" => "user", "content" => "Create a manual log workflow" }],
      )
    operations = [
      {
        op: "add_node",
        client_id: "manual-trigger",
        node: {
          type: "trigger:manual",
          name: "Manual trigger",
          position: {
            x: 0,
            y: 0,
          },
        },
      },
      {
        op: "add_node",
        client_id: "write-log",
        node: {
          type: "action:log",
          name: "Write log",
          position: {
            x: 200,
            y: 0,
          },
          parameters: {
            entries: {
              values: [{ key: "message", value: "hello" }],
            },
          },
        },
      },
      { op: "add_connection", from: "manual-trigger", to: "write-log" },
    ]
    raw_response = <<~TEXT
      Here is the draft patch:

      ```json
      #{
      JSON.pretty_generate(
        status: "proposed_patch",
        message: "Create a manual log workflow",
        questions: [],
        proposal: {
          workflow_name: "Manual log workflow",
          summary: "Run a manual trigger and write a log entry.",
          risk_level: "low",
          operations: operations,
        },
      )
    }
      ```
    TEXT
    fake_bot = double

    allow(fake_bot).to receive(:reply).and_return([[raw_response, "system"]])
    allow(DiscourseAi::Agents::Bot).to receive(:as).and_return(fake_bot)

    described_class.new.execute(
      session_id: session.id,
      user_id: admin.id,
      generation_id: SecureRandom.hex,
    )

    expect(session.reload).to have_attributes(status: "proposal_ready", risk_level: "low")
    expect(session.latest_response).to include("message" => "Create a manual log workflow")
    expect(session.latest_response.dig("proposal", "patch_validation")).to include(
      "valid" => true,
      "errors" => [],
    )
  end
end
