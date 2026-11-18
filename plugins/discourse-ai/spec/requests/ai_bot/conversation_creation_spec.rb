# frozen_string_literal: true

RSpec.describe "AI bot conversation creation" do
  fab!(:current_user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:other_user, :user)
  fab!(:llm_model) { Fabricate(:llm_model, name: "gpt-4") }

  before do
    enable_current_plugin
    toggle_enabled_bots(bots: [llm_model])
    SiteSetting.ai_bot_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
    SiteSetting.personal_message_enabled_groups = Group::AUTO_GROUPS[:staff]
    sign_in(current_user)
  end

  it "denies regular PM creation" do
    expect do
      post "/posts.json",
           params: {
             raw: "This normal personal message should not be created.",
             title: "Normal personal message",
             archetype: Archetype.private_message,
             target_recipients: other_user.username,
           }
    end.not_to change { Topic.private_messages_for_user(current_user).count }

    expect(response.status).to eq(422)
    expect(response.parsed_body["errors"]).to include(
      I18n.t("activerecord.errors.models.topic.attributes.base.cant_send_pm"),
    )

    expect do
      post "/discourse-ai/ai-bot/conversations.json",
           params: {
             raw: "This bot conversation route must not create a regular PM.",
             target_username: other_user.username,
           }
    end.not_to change { Topic.private_messages_for_user(current_user).count }

    expect(response.status).to eq(403)
  end

  it "keeps regular AI bot PM creation denied through the posts endpoint" do
    bot_user = llm_model.reload.user

    expect do
      post "/posts.json",
           params: {
             raw: "This AI bot personal message should not be created through posts.",
             title: "AI bot personal message",
             archetype: Archetype.private_message,
             target_recipients: bot_user.username,
           }
    end.not_to change { Topic.private_messages_for_user(current_user).count }

    expect(response.status).to eq(422)
    expect(response.parsed_body["errors"]).to include(
      I18n.t("activerecord.errors.models.topic.attributes.base.cant_send_pm"),
    )
  end

  it "allows creating and using an AI bot conversation" do
    bot_user = llm_model.reload.user

    expect do
      post "/discourse-ai/ai-bot/conversations.json",
           params: {
             raw: "Please help me with this AI bot conversation.",
             target_username: bot_user.username,
           }
    end.to change { Topic.private_messages_for_user(current_user).count }.by(1)

    expect(response.status).to eq(200)
    topic = Topic.find(response.parsed_body["topic_id"])
    expect(topic.allowed_users).to contain_exactly(current_user, bot_user)
    expect(topic.custom_fields[DiscourseAi::AiBot::TOPIC_AI_BOT_PM_FIELD]).to eq("t")

    get "/discourse-ai/ai-bot/conversations.json"

    expect(response.status).to eq(200)
    expect(
      response.parsed_body["conversations"].map { |conversation| conversation["id"] },
    ).to include(topic.id)

    post "/posts.json",
         params: {
           raw: "Here is a follow-up message for the AI bot.",
           topic_id: topic.id,
         }

    expect(response.status).to eq(200)
    expect(response.parsed_body["topic_id"]).to eq(topic.id)
  end

  it "allows a PM-enabled agent without a bot user" do
    bot_user = llm_model.reload.user
    agent =
      Fabricate(
        :ai_agent,
        allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
        allow_personal_messages: true,
      )

    expect do
      post "/discourse-ai/ai-bot/conversations.json",
           params: {
             raw: "Please run this PM-enabled agent in a bot conversation.",
             target_username: bot_user.username,
             ai_agent_id: agent.id,
           }
    end.to change { Topic.private_messages_for_user(current_user).count }.by(1)

    expect(response.status).to eq(200)
    topic = Topic.find(response.parsed_body["topic_id"])
    expect(topic.custom_fields["ai_agent_id"]).to eq(agent.id.to_s)
  end

  it "rejects a forged visible agent that is not allowed in personal messages" do
    bot_user = llm_model.reload.user
    forged_agent =
      Fabricate(
        :ai_agent,
        allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
        allow_personal_messages: false,
      )

    expect do
      post "/discourse-ai/ai-bot/conversations.json",
           params: {
             raw: "Please run this forged agent in a bot conversation.",
             target_username: bot_user.username,
             ai_agent_id: forged_agent.id,
           }
    end.not_to change { Topic.private_messages_for_user(current_user).count }

    expect(response.status).to eq(400)
  end

  it "uses AI bot access settings for bot conversations" do
    SiteSetting.ai_bot_allowed_groups = Group::AUTO_GROUPS[:staff]
    bot_user = llm_model.reload.user

    expect do
      post "/discourse-ai/ai-bot/conversations.json",
           params: {
             raw: "Please help me with this AI bot conversation.",
             target_username: bot_user.username,
           }
    end.not_to change { Topic.private_messages_for_user(current_user).count }

    expect(response.status).to eq(403)
  end

  context "when the agent researches a topic with a tag that only staff can see" do
    subject(:prompt_content) do
      DiscourseAi::Completions::Llm.with_prepared_responses(
        [research_call, "Research findings", "The topic has one tag.", "Topic tags"],
      ) do |_, _, prompts|
        Jobs::CreateAiReply.new.execute(reply_job_args)
        prompts.flat_map(&:messages).map { |message| message[:content].to_s }.join("\n")
      end
    end

    fab!(:public_tag) { Fabricate(:tag, name: "public-tag") }
    fab!(:staff_tag) { Fabricate(:tag, name: "staff-tag") }
    fab!(:staff_tag_group) do
      Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [staff_tag.name])
    end
    fab!(:tagged_post) { Fabricate(:post, topic: Fabricate(:topic, tags: [public_tag, staff_tag])) }
    fab!(:agent) do
      Fabricate(
        :ai_agent,
        allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
        allow_personal_messages: true,
        tools: ["Researcher"],
      )
    end

    let(:research_call) do
      DiscourseAi::Completions::ToolCall.new(
        id: "research-1",
        name: "researcher",
        parameters: {
          filter: "topic:#{tagged_post.topic_id}",
          goals: "List the tags of the topic",
        },
      )
    end
    let(:reply_job_args) { Jobs::CreateAiReply.jobs.last["args"].first.symbolize_keys }

    before do
      post "/discourse-ai/ai-bot/conversations.json",
           params: {
             raw: "Which tags does topic #{tagged_post.topic_id} have?",
             target_username: llm_model.reload.user.username,
             ai_agent_id: agent.id,
           }
    end

    it "omits the tag from the content sent to the LLM" do
      expect(prompt_content).not_to include(staff_tag.name)
    end

    it "keeps the public tag in the content sent to the LLM" do
      expect(prompt_content).to include(public_tag.name)
    end
  end
end
