# frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::BotController do
  fab!(:user)
  fab!(:pm_topic, :private_message_topic)
  fab!(:pm_post) { Fabricate(:post, topic: pm_topic) }
  fab!(:pm_post2) { Fabricate(:post, topic: pm_topic) }
  fab!(:pm_post3) { Fabricate(:post, topic: pm_topic) }

  before do
    enable_current_plugin
    sign_in(user)
  end

  describe "#show_debug_info" do
    before { SiteSetting.ai_bot_enabled = true }

    it "returns a 403 when the user cannot debug the AI bot conversation" do
      get "/discourse-ai/ai-bot/post/#{pm_post.id}/show-debug-info"
      expect(response.status).to eq(403)
    end

    it "returns debug info if the user can debug the AI bot conversation" do
      user = pm_topic.topic_allowed_users.first.user
      sign_in(user)

      log1 =
        AiApiAuditLog.create!(
          provider_id: 1,
          topic_id: pm_topic.id,
          raw_request_payload: "request",
          raw_response_payload: "response",
          request_tokens: 1,
          response_tokens: 2,
        )

      log2 =
        AiApiAuditLog.create!(
          post_id: pm_post.id,
          provider_id: 1,
          topic_id: pm_topic.id,
          raw_request_payload: "request",
          raw_response_payload: "response",
          request_tokens: 1,
          response_tokens: 2,
        )

      log3 =
        AiApiAuditLog.create!(
          post_id: pm_post2.id,
          provider_id: 1,
          topic_id: pm_topic.id,
          raw_request_payload: "request",
          raw_response_payload: "response",
          request_tokens: 1,
          response_tokens: 2,
        )

      Group.refresh_automatic_groups!
      SiteSetting.ai_bot_debugging_allowed_groups = user.groups.first.id.to_s

      get "/discourse-ai/ai-bot/post/#{pm_post.id}/show-debug-info"
      expect(response.status).to eq(200)

      expect(response.parsed_body["id"]).to eq(log2.id)
      expect(response.parsed_body["next_log_id"]).to eq(log3.id)
      expect(response.parsed_body["prev_log_id"]).to eq(log1.id)
      expect(response.parsed_body["topic_id"]).to eq(pm_topic.id)

      expect(response.parsed_body["request_tokens"]).to eq(1)
      expect(response.parsed_body["response_tokens"]).to eq(2)
      expect(response.parsed_body["raw_request_payload"]).to eq("request")
      expect(response.parsed_body["raw_response_payload"]).to eq("response")

      # return previous post if current has no debug info
      get "/discourse-ai/ai-bot/post/#{pm_post3.id}/show-debug-info"
      expect(response.status).to eq(200)
      expect(response.parsed_body["request_tokens"]).to eq(1)
      expect(response.parsed_body["response_tokens"]).to eq(2)

      # can return debug info by id as well
      get "/discourse-ai/ai-bot/show-debug-info/#{log1.id}"
      expect(response.status).to eq(200)
      expect(response.parsed_body["id"]).to eq(log1.id)
    end
  end

  describe "#stop_streaming_response" do
    let(:redis_stream_key) { "gpt_cancel:#{pm_post.id}" }

    before { Discourse.redis.setex(redis_stream_key, 60, 1) }

    it "returns a 403 when the user cannot see the PM" do
      post "/discourse-ai/ai-bot/post/#{pm_post.id}/stop-streaming"

      expect(response.status).to eq(403)
    end

    it "deletes the key using to track the streaming" do
      sign_in(pm_topic.topic_allowed_users.first.user)

      post "/discourse-ai/ai-bot/post/#{pm_post.id}/stop-streaming"

      expect(response.status).to eq(200)
      expect(Discourse.redis.get(redis_stream_key)).to be_nil
    end
  end

  describe "#retry_response" do
    fab!(:bot_user, :user)
    let!(:llm_model) { Fabricate(:llm_model, user: bot_user, enabled_chat_bot: true) }
    let!(:ai_persona) do
      Fabricate(
        :ai_persona,
        user: bot_user,
        default_llm_id: llm_model.id,
        allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
      )
    end
    let(:persona) { ai_persona.class_instance.new }
    let(:bot) { DiscourseAi::Personas::Bot.as(bot_user, persona: persona) }

    let!(:prompt_post) do
      Fabricate(:post, topic: pm_topic, user: user, raw: "Hello @#{bot_user.username}")
    end

    let!(:reply_post) do
      DiscourseAi::Completions::Llm.with_prepared_responses(["first try"]) do
        DiscourseAi::AiBot::Playground.new(bot).reply_to(prompt_post)
      end

      pm_topic.reload.posts.last
    end

    before do
      Group.refresh_automatic_groups!
      SiteSetting.ai_bot_enabled = true
      AiPersona.persona_cache.flush!

      tl0_group =
        Group.find_by(name: "trust_level_0") || Group.find(Group::AUTO_GROUPS[:trust_level_0])
      GroupUser.find_or_create_by!(user: user, group: tl0_group)
      user.reload

      pm_topic.topic_allowed_users.find_or_create_by!(user: user)

      unless pm_topic.topic_allowed_users.exists?(user: bot_user)
        pm_topic.topic_allowed_users.create!(user: bot_user)
      end
    end

    it "streams a replacement into the existing bot reply" do
      retry_text = "second attempt"

      DiscourseAi::Completions::Llm.with_prepared_responses([retry_text]) do
        post "/discourse-ai/ai-bot/post/#{reply_post.id}/retry"

        Jobs::CreateAiReply.new.execute(
          post_id: prompt_post.id,
          bot_user_id: bot_user.id,
          persona_id: reply_post.custom_fields[DiscourseAi::AiBot::POST_AI_PERSONA_ID_FIELD].to_i,
          reply_post_id: reply_post.id,
        )
      end

      expect(response.status).to eq(200)
      expect(reply_post.reload.raw).to eq(retry_text)
      expect(reply_post.custom_fields[DiscourseAi::AiBot::POST_AI_PERSONA_ID_FIELD].to_i).to eq(
        persona.id,
      )
    end

    it "returns a 404 when there is no previous non-bot prompt" do
      lone_topic = Fabricate(:private_message_topic)
      lone_topic.topic_allowed_users.create!(user: user)
      lone_topic.topic_allowed_users.create!(user: bot_user)
      bot_only_post = Fabricate(:post, topic: lone_topic, user: bot_user)

      post "/discourse-ai/ai-bot/post/#{bot_only_post.id}/retry"

      expect(response.status).to eq(404)
    end

    it "allows retrying if LLM model has a negative id (seeded)" do
      seeded_llm_model =
        Fabricate(
          :llm_model,
          id: -9999,
          user: bot_user,
          enabled_chat_bot: true,
          name: "second-model",
        )

      bot = DiscourseAi::Personas::Bot.as(bot_user, persona: persona, model: seeded_llm_model)
      DiscourseAi::Completions::Llm.with_prepared_responses(["first try"], llm: seeded_llm_model) do
        DiscourseAi::AiBot::Playground.new(bot).reply_to(prompt_post)
      end

      reply = pm_topic.reload.posts.last
      original_llm_id = reply.custom_fields[DiscourseAi::AiBot::POST_AI_LLM_MODEL_ID_FIELD]

      expect(original_llm_id.to_i).to eq(-9999)

      retry_text = "retry with original model"

      DiscourseAi::Completions::Llm.with_prepared_responses([retry_text], llm: seeded_llm_model) do
        post "/discourse-ai/ai-bot/post/#{reply.id}/retry"

        job_args = Jobs::CreateAiReply.jobs.last["args"].first
        expect(job_args["llm_model_id"]).to eq(-9999)

        Jobs::CreateAiReply.new.execute(job_args.symbolize_keys)
      end

      expect(response.status).to eq(200)
      expect(reply.reload.raw).to eq(retry_text)
    end

    it "uses the original LLM model when retrying even if persona default changed" do
      second_bot_user = Fabricate(:user)
      second_llm_model =
        Fabricate(:llm_model, user: second_bot_user, enabled_chat_bot: true, name: "second-model")

      pm_topic.topic_allowed_users.find_or_create_by!(user: second_bot_user)

      original_llm_name = reply_post.custom_fields[DiscourseAi::AiBot::POST_AI_LLM_NAME_FIELD]
      original_llm_id = reply_post.custom_fields[DiscourseAi::AiBot::POST_AI_LLM_MODEL_ID_FIELD]

      expect(original_llm_name).to be_present
      expect(original_llm_id.to_i).to eq(llm_model.id)

      ai_persona.update!(default_llm_id: second_llm_model.id)
      AiPersona.persona_cache.flush!

      retry_text = "retry with original model"

      DiscourseAi::Completions::Llm.with_prepared_responses([retry_text], llm: llm_model) do
        post "/discourse-ai/ai-bot/post/#{reply_post.id}/retry"

        job_args = Jobs::CreateAiReply.jobs.last["args"].first
        expect(job_args["llm_model_id"]).to eq(llm_model.id)

        Jobs::CreateAiReply.new.execute(job_args.symbolize_keys)
      end

      expect(response.status).to eq(200)
      expect(reply_post.reload.raw).to eq(retry_text)
      expect(reply_post.custom_fields[DiscourseAi::AiBot::POST_AI_LLM_NAME_FIELD]).to eq(
        original_llm_name,
      )
      expect(reply_post.custom_fields[DiscourseAi::AiBot::POST_AI_LLM_MODEL_ID_FIELD].to_i).to eq(
        original_llm_id.to_i,
      )
    end
  end

  describe "#show_bot_username" do
    it "returns the username_lower of the selected bot" do
      gpt_35_bot = Fabricate(:llm_model, name: "gpt-3.5-turbo")

      SiteSetting.ai_bot_enabled = true
      toggle_enabled_bots(bots: [gpt_35_bot])

      expected_username =
        DiscourseAi::AiBot::EntryPoint.find_user_from_model("gpt-3.5-turbo").username_lower

      get "/discourse-ai/ai-bot/bot-username", params: { username: gpt_35_bot.name }

      expect(response.status).to eq(200)
      expect(response.parsed_body["bot_username"]).to eq(expected_username)
    end
  end
end
