# frozen_string_literal: true

RSpec.describe DiscourseDataExplorer::AdminAssistant::CreateQuery do
  fab!(:admin)
  fab!(:llm_model) { Fabricate(:llm_model, name: "gpt-3.5-turbo") }
  fab!(:ai_agent) do
    Fabricate(
      :ai_agent,
      allowed_group_ids: [Group::AUTO_GROUPS[:admins]],
      require_approval: true,
    ).tap(&:create_user!)
  end
  fab!(:topic) do
    Fabricate(:private_message_topic, user: admin, recipient: Discourse.system_user).tap do |topic|
      topic.allowed_users << ai_agent.user
    end
  end
  fab!(:source_post) { Fabricate(:post, topic: topic, user: admin) }

  before do
    prepare_ai_bot_fixtures(bots: [llm_model])
    SiteSetting.data_explorer_enabled = true
    DiscourseDataExplorer::AdminAssistant::Capability.stubs(:status).returns(:available)
  end

  it "approves in a PM and appends a completion containing the saved query URL" do
    token =
      DiscourseDataExplorer::AdminAssistant::QueryDraft.sign(
        {
          name: "Recent users",
          description: "Lists recent users",
          sql: "SELECT id AS user_id FROM users",
        },
        user: admin,
      )
    action =
      AiToolAction.create!(
        tool_name: DiscourseDataExplorer::AdminAssistant::CreateQuery.name,
        tool_parameters: {
          draft_token: token,
          requester_id: admin.id,
        },
        ai_agent: ai_agent,
        bot_user_id: ai_agent.user_id,
        post_id: source_post.id,
      )
    reviewable =
      ReviewableAiToolAction.needs_review!(
        target: action,
        created_by: ai_agent.user,
        reviewable_by_moderator: true,
        payload: {
          llm_model_id: llm_model.id,
        },
      )
    approval_post =
      Fabricate(
        :post,
        topic: topic,
        user: ai_agent.user,
        raw: "<div data-ai-tool-approval-reviewable-id='#{reviewable.id}'></div>",
        custom_fields: {
          DiscourseAi::AiBot::POST_AI_AGENT_AUTHORIZATION_USER_ID_FIELD => admin.id,
        },
      )

    reviewable.perform(admin, :approve, post_id: approval_post.id)
    query = DiscourseDataExplorer::Query.order(:id).last
    url = "#{Discourse.base_url}/admin/plugins/discourse-data-explorer/queries/#{query.id}"
    prompts = nil

    DiscourseAi::Completions::Llm.with_prepared_responses(
      ["[Open the query](#{url})."],
    ) do |_, _, captured_prompts|
      Jobs::ResumeAiToolApproval.new.execute(reviewable_id: reviewable.id)
      prompts = captured_prompts
    end

    result = JSON.parse(prompts.first.messages.last[:content]).fetch("result")
    expect(result).to eq("status" => "success", "url" => url, "query_id" => query.id)
    expect(approval_post.reload.raw).to end_with("[Open the query](#{url}).")
  end
end
