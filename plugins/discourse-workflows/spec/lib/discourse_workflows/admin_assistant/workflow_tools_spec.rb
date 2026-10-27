# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::AdminAssistant::CreateWorkflow do
  fab!(:admin)
  fab!(:other_admin, :admin)
  fab!(:user)
  fab!(:ai_agent)

  let(:operations) do
    [
      {
        "op" => "add_node",
        "client_id" => "manual",
        "node" => {
          "type" => "trigger:manual",
          "name" => "Manual",
          "parameters" => {
          },
        },
      },
      {
        "op" => "add_node",
        "client_id" => "log",
        "node" => {
          "type" => "action:log",
          "name" => "Log",
          "parameters" => {
            "message" => "Hello",
          },
        },
      },
      { "op" => "add_connection", "from" => "manual", "to" => "log" },
    ]
  end
  let(:draft_attributes) { { name: "Manual log", operations: } }
  let(:agent_operations) do
    [
      {
        "op" => "create_ai_agent",
        "client_id" => "review-agent",
        "agent" => {
          "name" => "Workflow review agent",
          "description" => "Reviews content for this workflow.",
          "system_prompt" => "Review the supplied content and return a short result.",
        },
      },
      {
        "op" => "add_node",
        "client_id" => "manual",
        "node" => {
          "type" => "trigger:manual",
          "name" => "Manual",
          "parameters" => {
          },
        },
      },
      {
        "op" => "add_node",
        "client_id" => "review",
        "node" => {
          "type" => "action:ai_agent",
          "name" => "Review",
          "parameters" => {
            "agent_id" => {
              "$ref" => "review-agent",
            },
            "prompt" => "Review this workflow run.",
          },
        },
      },
      { "op" => "add_connection", "from" => "manual", "to" => "review" },
    ]
  end
  let(:token) do
    DiscourseWorkflows::AdminAssistant::WorkflowDraft.sign(draft_attributes, user: admin)
  end
  let(:context) { DiscourseAi::Agents::BotContext.new(user: admin, messages: []) }
  let(:tool) do
    described_class.new({ draft_token: token }, bot_user: Discourse.system_user, llm: nil, context:)
  end

  before do
    SiteSetting.discourse_ai_enabled = true
    SiteSetting.enable_discourse_workflows = true
    SiteSetting.discourse_workflows_ai_authoring_enabled = true
    DiscourseWorkflows::AdminAssistant::Capability.stubs(:status).returns(:available)
  end

  def build_reviewable(draft_token = token)
    action =
      AiToolAction.create!(
        tool_name: described_class.name,
        tool_parameters: {
          draft_token:,
          requester_id: admin.id,
        },
        ai_agent:,
        bot_user_id: Discourse.system_user.id,
      )
    item =
      ReviewableAiToolAction.needs_review!(
        target: action,
        created_by: Discourse.system_user,
        reviewable_by_moderator: true,
      )
    item.add_score(
      Discourse.system_user,
      ReviewableScore.types[:needs_approval],
      force_review: true,
    )
    item
  end

  it "requires mandatory approval and exposes the exact draft without its token" do
    expect(described_class.mandatory_approval?).to eq(true)
    expect(tool.approval_show_description?).to eq(true)
    details = tool.details
    expect(details).to include(
      "```admin-assistant-workflow",
      draft_attributes[:name],
      "trigger:manual",
      "action:log",
    )
    expect(details).not_to include(token)
    expect(PrettyText.cook(details)).to include('<code class="lang-admin-assistant-workflow">')
    expect(tool.approval_parameters).to be_empty
    expect { tool.invoke }.not_to change { DiscourseWorkflows::Workflow.count }
  end

  it "rejects secret-bearing script validation metadata in signed drafts" do
    tool.parameters[:draft_token] = DiscourseWorkflows::AdminAssistant::WorkflowDraft.sign(
      draft_attributes.merge(
        script_validations: [{ "valid" => false, "errors" => ["api_key: sensitive-value"] }],
      ),
      user: admin,
    )

    expect(tool.details).to eq(I18n.t("discourse_workflows.admin_assistant.secret_draft"))
    expect(tool.validation_error[:status]).to eq("error")
    expect { tool.invoke }.not_to change { DiscourseWorkflows::Workflow.count }
  end

  it "keeps malicious node text inert while preserving the exact configuration" do
    unsafe_attributes = {
      name: "Unsafe </code><script>alert(1)</script> ``` name",
      operations: [
        operations.first.deep_merge("node" => { "name" => "<img src=x onerror=alert(1)>" }),
      ],
    }
    unsafe_token =
      DiscourseWorkflows::AdminAssistant::WorkflowDraft.sign(unsafe_attributes, user: admin)
    unsafe_tool =
      described_class.new(
        { draft_token: unsafe_token },
        bot_user: Discourse.system_user,
        llm: nil,
        context:,
      )

    cooked = Nokogiri::HTML5.fragment(PrettyText.cook(unsafe_tool.details))
    code = cooked.at_css("code.lang-admin-assistant-workflow")

    expect(cooked.at_css("script, img")).to be_nil
    expect(JSON.parse(code.text).fetch("configuration")).to eq(
      unsafe_attributes.deep_stringify_keys,
    )
    expect(unsafe_tool.details).not_to include(unsafe_token)
  end

  it "creates the exact workflow as unpublished, credits the approver, and returns its URL" do
    item = build_reviewable

    expect { item.perform(other_admin, :approve) }.to change {
      DiscourseWorkflows::Workflow.count
    }.by(1)
    workflow = DiscourseWorkflows::Workflow.order(:id).last
    expect(workflow).to have_attributes(name: "Manual log", created_by_id: other_admin.id)
    expect(workflow).not_to be_published
    expect(workflow.nodes.map { |node| node["type"] }).to contain_exactly(
      "trigger:manual",
      "action:log",
    )
  end

  it "does not save rejected drafts" do
    item = build_reviewable
    expect { item.perform(admin, :reject) }.not_to change { DiscourseWorkflows::Workflow.count }
  end

  it "only creates a proposed AI agent after the workflow draft is approved" do
    agent_token =
      DiscourseWorkflows::AdminAssistant::WorkflowDraft.sign(
        { name: "AI review", operations: agent_operations },
        user: admin,
      )
    initial_tool =
      described_class.new(
        { draft_token: agent_token },
        bot_user: Discourse.system_user,
        llm: nil,
        context:,
      )

    expect { initial_tool.validation_error }.not_to change { AiAgent.count }
    item = build_reviewable(agent_token)
    expect { item.perform(other_admin, :approve) }.to change { AiAgent.count }.by(1)
    expect(AiAgent.find_by(name: "Workflow review agent")).to have_attributes(
      created_by_id: other_admin.id,
      system_prompt: "Review the supplied content and return a short result.",
    )
  end

  it "rejects non-admin requesters and approvers" do
    context.user = user
    expect(tool.validation_error[:status]).to eq("error")

    item = build_reviewable
    expect { item.perform(user, :approve) }.to raise_error(Reviewable::InvalidAction)
    expect(DiscourseWorkflows::Workflow.count).to eq(0)
  end

  it "rejects a draft requested by another admin before approval" do
    context.user = other_admin
    expect(tool.validation_error[:status]).to eq("error")
  end

  it "rejects a reviewable that is not bound to the signed requester" do
    item = build_reviewable
    item.target.tool_parameters["requester_id"] = other_admin.id
    item.target.save!

    expect { item.perform(other_admin, :approve) }.to raise_error(Discourse::InvalidAccess)
    expect(DiscourseWorkflows::Workflow.count).to eq(0)
  end

  it "requires the Core workflow management permission" do
    guardian = admin.guardian
    guardian.stubs(:can_manage_workflows?).returns(false)
    admin.stubs(:guardian).returns(guardian)

    expect(tool.validation_error[:status]).to eq("error")
  end

  it "rejects invalid and malformed graph drafts" do
    tool.parameters[:draft_token] = token + "tampered"
    expect(tool.validation_error[:status]).to eq("error")

    malformed =
      DiscourseWorkflows::AdminAssistant::WorkflowDraft.sign(
        { name: "Broken", operations: [{ op: "add_node", node: { type: "missing", name: "X" } }] },
        user: admin,
      )
    broken_tool =
      described_class.new(
        { draft_token: malformed },
        bot_user: Discourse.system_user,
        llm: nil,
        context:,
      )
    expect(broken_tool.validation_error[:error]).to eq(
      I18n.t("discourse_workflows.admin_assistant.invalid_graph"),
    )
  end

  it "rejects drafts containing raw secrets" do
    unsafe =
      DiscourseWorkflows::AdminAssistant::WorkflowDraft.sign(
        {
          name: "Unsafe",
          operations: [
            {
              op: "add_node",
              node: {
                type: "action:log",
                name: "Log",
                parameters: {
                  api_key: "raw-secret",
                },
              },
            },
          ],
        },
        user: admin,
      )
    unsafe_tool =
      described_class.new(
        { draft_token: unsafe },
        bot_user: Discourse.system_user,
        llm: nil,
        context:,
      )

    expect(unsafe_tool.validation_error[:error]).to eq(
      I18n.t("discourse_workflows.admin_assistant.secret_draft"),
    )
  end

  it "rechecks capability and the requester's admin status at approval time" do
    item = build_reviewable
    DiscourseWorkflows::AdminAssistant::Capability.stubs(:status).returns(:disabled)
    expect { item.perform(admin, :approve) }.to raise_error(Discourse::InvalidAccess)
    expect(item.reload).to be_pending

    DiscourseWorkflows::AdminAssistant::Capability.stubs(:status).returns(:available)
    admin.update!(admin: false)
    expect { item.perform(other_admin, :approve) }.to raise_error(Discourse::InvalidAccess)
    expect(item.reload).to be_pending
  end

  it "prevents replay through a second approval" do
    first = build_reviewable
    second = build_reviewable

    first.perform(admin, :approve)
    expect { second.perform(other_admin, :approve) }.to raise_error(Discourse::InvalidAccess)
    expect(DiscourseWorkflows::Workflow.count).to eq(1)
  end

  it "rolls back AI-agent side effects and releases the claim with the approval transaction" do
    agent_token =
      DiscourseWorkflows::AdminAssistant::WorkflowDraft.sign(
        { name: "AI review", operations: agent_operations },
        user: admin,
      )
    item = build_reviewable(agent_token)
    replay_context = DiscourseAi::Agents::BotContext.new(user: other_admin, messages: [])
    replay_context.reviewable_id = item.id
    replay_tool =
      described_class.new(
        { draft_token: agent_token, requester_id: admin.id },
        bot_user: Discourse.system_user,
        llm: nil,
        context: replay_context,
      )

    expect do
      expect do
        DiscourseWorkflows::Workflow.transaction(requires_new: true) do
          expect(replay_tool.invoke[:status]).to eq("success")
          expect(AiAgent.find_by(name: "Workflow review agent")).to be_present
          raise ActiveRecord::Rollback
        end
      end.not_to change { DiscourseWorkflows::Workflow.count }
    end.not_to change { AiAgent.count }
    expect(
      DiscourseWorkflows::AdminAssistant::WorkflowDraft.claim(agent_token, reviewable_id: item.id),
    ).to eq(true)
    DiscourseWorkflows::AdminAssistant::WorkflowDraft.release(agent_token, reviewable_id: item.id)
  end

  it "hides tools and authoring instructions when public capability is unavailable" do
    DiscourseWorkflows::AdminAssistant::Capability.stubs(:status).returns(:unconfigured)
    context = DiscourseAi::Agents::BotContext.new(user: admin, messages: [])
    assistant = DiscourseAi::Agents::DiscourseAdminAssistant.new

    expect(assistant.runtime_tools(context:)).not_to include(
      DiscourseWorkflows::AdminAssistant::GenerateWorkflow,
      described_class,
    )
    expect(assistant.craft_prompt(context).system_message_text).not_to include(
      "call generate_workflow",
    )
  end

  it "registers both workflow tools for the admin assistant and pending replay" do
    tools = DiscourseAi::Agents::DiscourseAdminAssistant.new.tools
    expect(tools).to include(DiscourseWorkflows::AdminAssistant::GenerateWorkflow, described_class)
    expect(DiscourseAi::Agents::Agent.external_tool_by_name("CreateWorkflow")).to eq(
      described_class,
    )
    expect(DiscourseAi::Agents::Agent.external_tool_by_name("GenerateWorkflow")).to eq(
      DiscourseWorkflows::AdminAssistant::GenerateWorkflow,
    )
    prompt =
      DiscourseAi::Agents::DiscourseAdminAssistant.new.craft_prompt(
        DiscourseAi::Agents::BotContext.new(user: admin, messages: []),
      )
    expect(prompt.system_message_text).to include(
      "explicit human approval",
      "needs_clarification",
      "unpublished",
    )
  end
end

RSpec.describe DiscourseWorkflows::AdminAssistant::GenerateWorkflow do
  fab!(:admin)

  let(:context) { DiscourseAi::Agents::BotContext.new(user: admin, messages: []) }
  let(:tool) do
    described_class.new(
      { description: "Create a manual workflow that logs Hello" },
      bot_user: Discourse.system_user,
      llm: nil,
      context:,
    )
  end
  let(:proposal) do
    {
      "title" => "Manual log",
      "summary" => "Logs a message when run manually",
      "operations" => [
        {
          "op" => "add_node",
          "client_id" => "manual",
          "node" => {
            "type" => "trigger:manual",
            "name" => "Manual",
            "parameters" => {
            },
          },
        },
      ],
    }
  end

  before do
    SiteSetting.enable_discourse_workflows = true
    DiscourseWorkflows::AdminAssistant::Capability.stubs(:status).returns(:available)
    allow_any_instance_of(Jobs::DiscourseWorkflows::AuthorWithAi).to receive(
      :execute,
    ) do |_job, args|
      DiscourseWorkflows::AiAuthoringSession.find(args[:session_id]).update!(
        status: "proposal_ready",
        proposed_patch: proposal,
      )
    end
  end

  it "generates and validates a signed draft without saving a workflow" do
    result = nil
    expect { result = tool.invoke }.not_to change { DiscourseWorkflows::Workflow.count }

    expect(result[:status]).to eq("success")
    expect(result[:draft_token]).to match(/\Aworkflow_authoring_draft_[0-9a-f]{32}\z/)
    expect(DiscourseWorkflows::AdminAssistant::WorkflowDraft.read(result[:draft_token])).to include(
      name: "Manual log",
      operations: proposal["operations"],
      user_id: admin.id,
    )
    expect(DiscourseWorkflows::AiAuthoringSession.count).to eq(0)
  end

  it "preserves passed and failed script checks in the signed draft and approval preview" do
    proposal["operations"] += [
      {
        "op" => "add_node",
        "client_id" => "code",
        "node" => {
          "type" => "action:code",
          "name" => "Process items",
          "parameters" => {
            "mode" => "runOnceForEachItem",
            "code" => "var items = $input.all(); return items;",
          },
        },
      },
      { "op" => "add_connection", "from" => "manual", "to" => "code" },
    ]
    [true, false].each do |valid|
      validations = [
        {
          "operation_index" => 1,
          "node_name" => "Process items",
          "mode" => "runOnceForEachItem",
          "valid" => valid,
          "errors" => valid ? [] : ["$input.all is only available in runOnceForAllItems mode"],
        },
      ]
      proposal["script_validations"] = validations
      result = nil
      expect { result = tool.invoke }.not_to change { DiscourseWorkflows::Workflow.count }
      expect(result[:status]).to eq("success")
      expect(result[:script_validations]).to eq(validations)
      expect(
        DiscourseWorkflows::AdminAssistant::WorkflowDraft.read(result[:draft_token])[
          :script_validations
        ],
      ).to eq(validations)

      creator =
        DiscourseWorkflows::AdminAssistant::CreateWorkflow.new(
          { draft_token: result[:draft_token] },
          bot_user: Discourse.system_user,
          llm: nil,
          context:,
        )
      code = Nokogiri::HTML5.fragment(PrettyText.cook(creator.details)).at_css("pre code")
      expect(JSON.parse(code.text).dig("configuration", "script_validations")).to eq(validations)
      expect(creator.validation_error).to be_nil
    end
  end

  it "does not return secret-bearing script validation metadata" do
    proposal["script_validations"] = [
      { "valid" => false, "errors" => ["api_key: sensitive-value"] },
    ]

    result = tool.invoke
    expect(result[:status]).to eq("error")
    expect(result[:draft_token]).to be_nil
    expect(result[:script_validations]).to be_nil
    expect(DiscourseWorkflows::AiAuthoringSession.count).to eq(0)
  end

  it "rejects non-admin users and unavailable capability" do
    context.user = Fabricate(:user)
    expect(tool.invoke[:status]).to eq("error")

    context.user = admin
    DiscourseWorkflows::AdminAssistant::Capability.stubs(:status).returns(:unconfigured)
    expect(tool.invoke[:status]).to eq("error")
  end

  it "does not forward secret-bearing requests to workflow authoring" do
    expect_any_instance_of(Jobs::DiscourseWorkflows::AuthorWithAi).not_to receive(:execute)

    [
      "Use API key: raw-secret-value",
      "POST to https://admin:secret@example.com/hook",
      "Use -----BEGIN PRIVATE KEY----- raw-private-key",
      "Use eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.signature123",
    ].each do |description|
      tool.parameters[:description] = description
      expect(tool.invoke[:status]).to eq("error")
    end
  end

  it "returns Core clarification questions without losing them" do
    questions = [
      {
        "id" => "scope",
        "question" => "Which topics should run this workflow?",
        "multi_select" => false,
        "custom_allowed" => true,
        "options" => [
          { "label" => "All topics", "description" => "Run everywhere." },
          { "label" => "Support", "description" => "Run in support categories." },
        ],
      },
    ]
    allow_any_instance_of(Jobs::DiscourseWorkflows::AuthorWithAi).to receive(
      :execute,
    ) do |_job, args|
      DiscourseWorkflows::AiAuthoringSession.find(args[:session_id]).update!(
        status: "needs_clarification",
        latest_response: {
          "status" => "needs_clarification",
          "message" => "I need the topic scope.",
          "questions" => questions,
        },
      )
    end

    result = tool.invoke

    expect(result).to eq(
      status: "needs_clarification",
      message: "I need the topic scope.",
      questions:,
    )
    expect(DiscourseWorkflows::AiAuthoringSession.count).to eq(0)
  end

  it "does not create proposed AI agents while authoring or validating a draft" do
    proposal["operations"] = [
      {
        "op" => "create_ai_agent",
        "client_id" => "draft-agent",
        "agent" => {
          "name" => "Workflow draft agent",
          "description" => "Reviews workflow input.",
          "system_prompt" => "Review the input and return a short result.",
        },
      },
      {
        "op" => "add_node",
        "client_id" => "manual",
        "node" => {
          "type" => "trigger:manual",
          "name" => "Manual",
          "parameters" => {
          },
        },
      },
      {
        "op" => "add_node",
        "client_id" => "review",
        "node" => {
          "type" => "action:ai_agent",
          "name" => "Review",
          "parameters" => {
            "agent_id" => {
              "$ref" => "draft-agent",
            },
            "prompt" => "Review this run.",
          },
        },
      },
      { "op" => "add_connection", "from" => "manual", "to" => "review" },
    ]

    expect { expect(tool.invoke[:status]).to eq("success") }.not_to change { AiAgent.count }
    expect(AiAgent.find_by(name: "Workflow draft agent")).to be_nil
  end

  it "rejects malformed or secret-bearing generated proposals" do
    proposal["operations"] = [{ "op" => "unknown" }]
    expect(tool.invoke[:status]).to eq("error")

    proposal["operations"] = [
      {
        "op" => "add_node",
        "node" => {
          "type" => "action:log",
          "name" => "Log",
          "parameters" => {
            "password" => "raw-secret",
          },
        },
      },
    ]
    expect(tool.invoke[:status]).to eq("error")
  end
end
