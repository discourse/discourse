# frozen_string_literal: true

RSpec.describe "AI agent chat tool approval" do
  fab!(:admin) { Fabricate(:admin, refresh_auto_groups: true) }

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
    sign_in(admin)
  end

  it "queues a suspension requested through the chat API for human approval" do
    fake_llm_model = Fabricate(:llm_model, name: "mandatory-approval-fake", provider: "fake")
    target_user = Fabricate(:user)
    agent =
      Fabricate(
        :ai_agent,
        allowed_group_ids: [Group::AUTO_GROUPS[:admins]],
        allow_chat_direct_messages: true,
        default_llm_id: fake_llm_model.id,
        require_approval: false,
        tools: ["SuspendUser"],
      )
    agent.create_user!
    channel = Fabricate(:direct_message_channel, users: [admin, agent.user])
    tool_call =
      DiscourseAi::Completions::ToolCall.new(
        id: "suspend-user",
        name: "suspend_user",
        parameters: {
          username: target_user.username,
          duration_days: 3,
          reason: "Requested in the chat conversation",
        },
      )

    post "/chat/#{channel.id}.json", params: { message: "Suspend @#{target_user.username}." }

    expect(response.status).to eq(200)
    expect(response.parsed_body["message_id"]).to be_present

    job_args = Jobs::CreateAiChatReply.jobs.last["args"].first.symbolize_keys
    DiscourseAi::Completions::Llm.with_prepared_responses([tool_call, "Awaiting approval."]) do
      Jobs::CreateAiChatReply.new.execute(job_args)
    end

    expect(target_user.reload.suspended?).to eq(false)
    expect(ReviewableAiToolAction.count).to eq(1)
  end
end
