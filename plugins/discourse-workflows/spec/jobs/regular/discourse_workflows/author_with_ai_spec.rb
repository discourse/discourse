# frozen_string_literal: true

RSpec.describe Jobs::DiscourseWorkflows::AuthorWithAi do
  fab!(:admin)
  fab!(:ai_agent)

  before do
    SiteSetting.discourse_workflows_ai_authoring_enabled = true
    SiteSetting.discourse_workflows_workflow_authoring_agent = ai_agent.id
  end

  def authoring_result_raw_context(payload, tool_call_id: "tool-call-id")
    [
      [
        { arguments: payload }.to_json,
        tool_call_id,
        "tool_call",
        DiscourseWorkflows::Ai::Tools::WorkflowAuthoringResult.name,
      ],
      [
        payload.to_json,
        tool_call_id,
        "tool",
        DiscourseWorkflows::Ai::Tools::WorkflowAuthoringResult.name,
      ],
    ]
  end

  it "passes persisted messages to the AI bot with valid types" do
    session =
      Fabricate(
        :discourse_workflows_ai_authoring_session,
        user: admin,
        messages: [{ "type" => "user", "content" => "Create a workflow" }],
      )
    captured_messages = nil
    fake_bot = double
    response = {
      status: "needs_clarification",
      message: "Which category should trigger it?",
      questions: [
        {
          id: "category",
          question: "Which category?",
          options: [
            { label: "Support", description: "Support category" },
            { label: "All", description: "All categories" },
          ],
        },
      ],
      proposal: {
      },
    }

    allow(fake_bot).to receive(:reply) do |context|
      captured_messages = context.messages
      authoring_result_raw_context(response)
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

  it "publishes progress for agent tool and response updates", :aggregate_failures do
    session =
      Fabricate(
        :discourse_workflows_ai_authoring_session,
        user: admin,
        messages: [{ "type" => "user", "content" => "Create a workflow" }],
      )
    generation_id = SecureRandom.hex
    fake_bot = double
    response = { status: "explanation", message: "No changes needed", questions: [], proposal: {} }

    allow(fake_bot).to receive(:reply) do |_context, &block|
      block.call("", "**Read workflow node catalog**\nChecking node schemas\n\n", :thinking)
      block.call("**Read workflow node catalog**\nFound matching nodes\n\n", nil, :thinking)
      block.call("", "**Return workflow authoring result**\nPreparing final result\n\n", :thinking)
      block.call(
        "**Return workflow authoring result**\nReturned workflow authoring result\n\n",
        nil,
        :thinking,
      )
      authoring_result_raw_context(response)
    end
    allow(DiscourseAi::Agents::Bot).to receive(:as).and_return(fake_bot)

    messages =
      MessageBus.track_publish("/discourse-workflows/ai-authoring/#{generation_id}") do
        described_class.new.execute(
          session_id: session.id,
          user_id: admin.id,
          generation_id: generation_id,
        )
      end
    progress = messages.map(&:data).select { |data| data[:status] == "progress" }

    expect(progress.map { |data| data[:message] }).to include(
      "Using Read workflow node catalog",
      "Finished Read workflow node catalog",
      "Using Return workflow authoring result",
      "Finished Return workflow authoring result",
    )
    expect(progress.map { |data| data[:stage] }).to include("agent_update")
  end

  it "highlights trigger author trust-level fields in AI context", :aggregate_failures do
    session =
      Fabricate(
        :discourse_workflows_ai_authoring_session,
        user: admin,
        messages: [{ "type" => "user", "content" => "Create a TL1 post workflow" }],
      )
    captured_custom_instructions = nil
    fake_bot = double
    response = { status: "explanation", message: "No changes needed", questions: [], proposal: {} }

    allow(fake_bot).to receive(:reply) do |context|
      captured_custom_instructions = context.custom_instructions
      authoring_result_raw_context(response)
    end
    allow(DiscourseAi::Agents::Bot).to receive(:as).and_return(fake_bot)
    allow(DiscourseWorkflows::Ai::Tools::SearchChatChannels).to receive(:available?).and_return(
      true,
    )

    described_class.new.execute(
      session_id: session.id,
      user_id: admin.id,
      generation_id: SecureRandom.hex,
    )

    expect(captured_custom_instructions).to include(
      "trigger:post_created exposes the created post under post.*",
      "user.trust_level",
      "do not assume post.trust_level",
      "Full graph and node catalog are intentionally not preloaded",
      "Do not ask whether trust level is available",
    )
    payload_json = captured_custom_instructions.split("tools for details:\n", 2).last
    payload = JSON.parse(payload_json)
    expect(payload).not_to have_key("node_catalog")
    expect(payload).not_to have_key("workflow_graph")
    expect(payload.dig("context_tools", "workflow_node_catalog")).to include("node parameters")
    expect(payload.dig("context_tools", "workflow_graph_context")).to include("current graph")
    expect(payload.dig("context_tools", "search_chat_channels")).to include("never invent")
    expect(payload.dig("context_tools", "workflow_validate_script")).to include("exact Code node")
    expect(payload.dig("context_tools", "workflow_authoring_result")).to include("final response")
    expect(payload["trigger_author_field_facts"]).to include(
      a_string_including("trigger:post_created"),
    )
  end

  it "uses authoring result tool calls for patch proposals", :aggregate_failures do
    workflow = Fabricate(:discourse_workflows_workflow, created_by: admin)
    session =
      Fabricate(
        :discourse_workflows_ai_authoring_session,
        user: admin,
        workflow: workflow,
        messages: [{ "type" => "user", "content" => "Create a manual workflow" }],
      )
    operations = [
      {
        op: "add_node",
        client_id: "manual-trigger",
        node: {
          type: "trigger:manual",
          name: "Manual trigger",
        },
      },
    ]
    response = {
      status: "proposed_patch",
      message: "Create a manual workflow",
      questions: [],
      proposal: {
        title: "Manual workflow",
        summary: "Start with a manual trigger.",
        risk_level: "low",
        operations: operations,
      },
    }
    fake_bot = double

    allow(fake_bot).to receive(:reply).and_return(authoring_result_raw_context(response))
    allow(DiscourseAi::Agents::Bot).to receive(:as).and_return(fake_bot)

    described_class.new.execute(
      session_id: session.id,
      user_id: admin.id,
      generation_id: SecureRandom.hex,
    )

    expect(session.reload).to have_attributes(status: "proposal_ready", risk_level: "low")
    expect(session.latest_response).to include("message" => "Create a manual workflow")
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
        latest_request:
          '{"type":"workflow_ask_questions_result","answers":[{"id":"trigger_scope","selected_options":["First post only"]}]}',
        messages: [
          {
            "type" => "user",
            "content" =>
              JSON.pretty_generate(
                {
                  mode: "edit",
                  message: "Create a manual workflow after asking questions",
                  workflow_id: workflow.id,
                },
              ),
          },
          {
            "type" => "user",
            "content" =>
              JSON.pretty_generate(
                {
                  mode: "edit",
                  message:
                    '{"type":"workflow_ask_questions_result","answers":[{"id":"trigger_scope","selected_options":["First post only"]}]}',
                  workflow_id: workflow.id,
                },
              ),
          },
        ],
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
    expect(session.proposed_patch["title"]).to eq("Create a manual workflow after asking questions")
    expect(session.proposed_patch.dig("patch_validation", "valid")).to eq(true)
  end

  it "falls back to validated patch tool calls when the final result omits operations",
     :aggregate_failures do
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
        "validate-patch-call-id",
        "tool_call",
        "workflow_validate_patch",
      ],
      [
        { status: "success", valid: true }.to_json,
        "validate-patch-call-id",
        "tool",
        "workflow_validate_patch",
      ],
      [
        {
          status: "error",
          message: "Proposed patch results must include proposal.operations",
          questions: [],
          proposal: {
          },
        }.to_json,
        "authoring-result-call-id",
        "tool",
        DiscourseWorkflows::Ai::Tools::WorkflowAuthoringResult.name,
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
    expect(session.proposed_patch["title"]).to eq("Create a manual workflow")
    expect(session.proposed_patch["operations"]).to eq(JSON.parse(operations.to_json))
    expect(session.proposed_patch.dig("patch_validation", "valid")).to eq(true)
  end

  it "stores Code node validation errors in the response", :aggregate_failures do
    session =
      Fabricate(
        :discourse_workflows_ai_authoring_session,
        user: admin,
        messages: [{ "type" => "user", "content" => "Create a workflow with code" }],
      )
    operations = [
      {
        op: "add_node",
        client_id: "bad-code",
        node: {
          type: "action:code",
          name: "Merge post data with result",
          parameters: {
            mode: "runOnceForEachItem",
            code: "var items = $input.all();\nreturn items;",
          },
        },
      },
    ]
    response = {
      status: "proposed_patch",
      message: "Create a workflow with code",
      questions: [],
      proposal: {
        title: "Code workflow",
        summary: "Adds a Code node.",
        risk_level: "medium",
        operations: operations,
      },
    }
    fake_bot = double

    allow(fake_bot).to receive(:reply).and_return(authoring_result_raw_context(response))
    allow(DiscourseAi::Agents::Bot).to receive(:as).and_return(fake_bot)

    described_class.new.execute(
      session_id: session.id,
      user_id: admin.id,
      generation_id: SecureRandom.hex,
    )

    expect(session.reload).to have_attributes(status: "error")
    expect(session.latest_response["message"]).to include(
      "Merge post data with result: $input.all is only available in runOnceForAllItems mode",
    )
    expect(session.proposed_patch["script_validations"]).to contain_exactly(
      include(
        "node_name" => "Merge post data with result",
        "valid" => false,
        "errors" => ["$input.all is only available in runOnceForAllItems mode"],
      ),
    )
  end

  it "requires a tool call for the final authoring result" do
    session =
      Fabricate(
        :discourse_workflows_ai_authoring_session,
        user: admin,
        messages: [{ "type" => "user", "content" => "Create a manual log workflow" }],
      )
    fake_bot = double
    raw_response = {
      status: "proposed_patch",
      message: "Create a manual log workflow",
      questions: [],
      proposal: {
        operations: [{ op: "add_node", client_id: "manual-trigger" }],
      },
    }.to_json

    allow(fake_bot).to receive(:reply).and_return([[raw_response, "system"]])
    allow(DiscourseAi::Agents::Bot).to receive(:as).and_return(fake_bot)

    described_class.new.execute(
      session_id: session.id,
      user_id: admin.id,
      generation_id: SecureRandom.hex,
    )

    expect(session.reload).to have_attributes(status: "error")
  end
end
