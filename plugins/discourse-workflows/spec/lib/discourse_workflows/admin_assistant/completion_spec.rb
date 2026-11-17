# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::AdminAssistant::CreateWorkflow do
  fab!(:admin)
  fab!(:llm_model) { Fabricate(:llm_model, name: "gpt-3.5-turbo") }
  fab!(:ai_agent) do
    Fabricate(
      :ai_agent,
      allowed_group_ids: [Group::AUTO_GROUPS[:admins]],
      allow_chat_direct_messages: true,
      require_approval: true,
    ).tap(&:create_user!)
  end

  before do
    prepare_ai_bot_fixtures(bots: [llm_model])
    SiteSetting.chat_enabled = true
    DiscourseWorkflows::AdminAssistant::Capability.stubs(:status).returns(:available)
  end

  it "approves in chat and presents the saved workflow URL through generic continuation" do
    channel = Fabricate(:direct_message_channel, users: [admin, ai_agent.user])
    source_message = Fabricate(:chat_message, chat_channel: channel, user: admin)
    operations = [
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
    ]
    token =
      DiscourseWorkflows::AdminAssistant::WorkflowDraft.sign(
        { name: "Manual workflow", operations: operations },
        user: admin,
      )
    action =
      AiToolAction.create!(
        tool_name: DiscourseWorkflows::AdminAssistant::CreateWorkflow.name,
        tool_parameters: {
          draft_token: token,
          requester_id: admin.id,
        },
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
          llm_model_id: llm_model.id,
        },
      )
    approval_message =
      Fabricate(
        :chat_message,
        chat_channel: channel,
        user: ai_agent.user,
        blocks: DiscourseAi::AiBot::ChatToolApproval.pending_blocks(reviewable.id),
      )

    reviewable.perform(admin, :approve, chat_message_id: approval_message.id)
    workflow = DiscourseWorkflows::Workflow.order(:id).last
    url = "#{Discourse.base_url}/admin/plugins/discourse-workflows/workflows/#{workflow.id}"
    prompts = nil

    DiscourseAi::Completions::Llm.with_prepared_responses(
      ["[Open the workflow](#{url})."],
    ) do |_, _, captured_prompts|
      Jobs::ResumeAiToolApproval.new.execute(reviewable_id: reviewable.id)
      prompts = captured_prompts
    end

    result = JSON.parse(prompts.first.messages.last[:content]).fetch("result")
    expect(result).to eq("status" => "success", "url" => url, "workflow_id" => workflow.id)
    expect(channel.chat_messages.order(:id).last.message).to eq("[Open the workflow](#{url}).")
    expect(workflow).not_to be_published
  end
end
