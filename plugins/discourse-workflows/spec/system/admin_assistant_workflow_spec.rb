# frozen_string_literal: true

RSpec.describe "Admin Assistant workflow approval preview" do
  fab!(:admin) { Fabricate(:admin, refresh_auto_groups: true) }
  fab!(:ai_agent) do
    Fabricate(
      :ai_agent,
      allowed_group_ids: [Group::AUTO_GROUPS[:admins]],
      allow_chat_direct_messages: true,
      require_approval: true,
    ).tap(&:create_user!)
  end

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:operations) do
    [
      {
        "op" => "add_node",
        "client_id" => "manual",
        "node" => {
          "type" => "trigger:manual",
          "name" => "Manual trigger",
          "parameters" => {
          },
        },
      },
      {
        "op" => "add_node",
        "client_id" => "accepted",
        "node" => {
          "type" => "action:log",
          "name" => "Record accepted topic",
          "parameters" => {
            "message" => "Accepted",
          },
        },
      },
      { "op" => "add_connection", "from" => "manual", "to" => "accepted" },
    ]
  end

  before do
    SiteSetting.discourse_ai_enabled = true
    SiteSetting.ai_bot_enabled = true
    SiteSetting.enable_discourse_workflows = true
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
    DiscourseWorkflows::AdminAssistant::Capability.stubs(:status).returns(:available)
    sign_in(admin)
  end

  it "shows the exact graph before controls and saves only after approval" do
    channel = Fabricate(:direct_message_channel, users: [admin, ai_agent.user])
    source_message = Fabricate(:chat_message, chat_channel: channel, user: admin)
    token =
      DiscourseWorkflows::AdminAssistant::WorkflowDraft.sign(
        { name: "Topic triage", operations: operations },
        user: admin,
      )
    context = DiscourseAi::Agents::BotContext.new(user: admin, messages: [])
    tool =
      DiscourseWorkflows::AdminAssistant::CreateWorkflow.new(
        { draft_token: token, requester_id: admin.id },
        bot_user: ai_agent.user,
        llm: nil,
        context: context,
      )
    action =
      AiToolAction.create!(
        tool_name: tool.name,
        tool_parameters: tool.parameters,
        ai_agent: ai_agent,
        bot_user_id: ai_agent.user_id,
      )
    reviewable =
      ReviewableAiToolAction.needs_review!(
        target: action,
        created_by: ai_agent.user,
        reviewable_by_moderator: true,
        payload: {
          chat_message_id: source_message.id,
        },
      )
    reviewable.add_score(
      Discourse.system_user,
      ReviewableScore.types[:needs_approval],
      force_review: true,
    )
    approval_message =
      Fabricate(
        :chat_message,
        chat_channel: channel,
        user: ai_agent.user,
        message: tool.details,
        blocks:
          DiscourseAi::AiBot::ChatToolApproval.pending_blocks(
            reviewable.id,
            info: {
              summary: tool.summary,
              details: tool.details,
              question: tool.approval_question,
              parameters: [],
            },
          ),
      )

    expect { chat_page.visit_channel(channel) }.not_to change { DiscourseWorkflows::Workflow.count }
    expect(page).to have_css(
      ".chat-confirmation__description .assistant-workflow-preview",
      text: "Topic triage",
    )
    expect(page).to have_css(".assistant-workflow-preview__node", count: 2)
    expect(page).to have_css(".assistant-workflow-preview__connection", count: 1)
    expect(page).to have_css(".assistant-workflow-preview details:not([open])")
    expect(page.html).not_to include(token)
    expect(page.evaluate_script(<<~JS)).to eq(true)
      document.querySelector(".assistant-workflow-preview").compareDocumentPosition(
        document.querySelector(".chat-confirmation__footer")
      ) === Node.DOCUMENT_POSITION_FOLLOWING
    JS

    click_button(I18n.t("discourse_ai.ai_bot.chat_tool_approval.approve_label"))

    expect(page).to have_text("Approved by @#{admin.username}")
    workflow = DiscourseWorkflows::Workflow.order(:id).last
    expect(workflow).to have_attributes(name: "Topic triage", created_by_id: admin.id)
    expect(workflow).not_to be_published
    url = "#{Discourse.base_url}/admin/plugins/discourse-workflows/workflows/#{workflow.id}"
    expect(reviewable.reload.payload["continuation"]).to eq(
      "chat_message_id" => approval_message.id,
      "tool_result" => {
        "status" => "success",
        "workflow_id" => workflow.id,
        "url" => url,
      },
    )
  end
end
