# frozen_string_literal: true

RSpec.describe Jobs::CreateAiReply do
  subject(:job) { described_class.new }

  fab!(:gpt_35_bot) { Fabricate(:llm_model, name: "gpt-3.5-turbo") }
  fab!(:agent) do
    Fabricate(
      :ai_agent,
      allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
      allow_personal_messages: true,
      allow_topic_mentions: true,
      default_llm: gpt_35_bot,
    ).tap(&:ensure_user!)
  end

  include_context "with AI bot enabled"

  before do
    SiteSetting.ai_bot_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
    toggle_enabled_bots(bots: [gpt_35_bot])
  end

  describe "#execute" do
    fab!(:topic)
    fab!(:post) { Fabricate(:post, topic: topic) }

    let(:expected_response) do
      "Hello this is a bot and what you just said is an interesting question"
    end

    before { SiteSetting.min_personal_message_post_length = 5 }

    it "adds an agent-authored reply with model and authorization provenance" do
      authorization_user = topic.first_post.user

      DiscourseAi::Completions::Llm.with_prepared_responses([expected_response]) do
        job.execute(
          post_id: topic.first_post.id,
          bot_user_id: agent.user_id,
          agent_id: agent.id,
          llm_model_id: gpt_35_bot.id,
          authorization_user_id: authorization_user.id,
        )
      end

      bot_reply = topic.posts.last
      expect(bot_reply.raw).to eq(expected_response)
      expect(bot_reply.user).to eq(agent.user)
      expect(bot_reply.custom_fields).to include(
        DiscourseAi::AiBot::POST_AI_LLM_MODEL_ID_FIELD => gpt_35_bot.id.to_s,
        DiscourseAi::AiBot::POST_AI_LLM_NAME_FIELD => gpt_35_bot.display_name,
        DiscourseAi::AiBot::POST_AI_AGENT_ID_FIELD => agent.id.to_s,
        DiscourseAi::AiBot::POST_AI_AGENT_AUTHORIZATION_USER_ID_FIELD => authorization_user.id.to_s,
      )
    end

    it "summarizes earlier PM turns and preserves the latest request when it repeats an earlier one" do
      gpt_35_bot.update!(max_prompt_tokens: 8000, max_output_tokens: 1000)
      author = Fabricate(:user, refresh_auto_groups: true)
      pm_topic = Fabricate(:private_message_topic, user: author, recipient: agent.user)
      repeated_request = "Please continue."
      Fabricate(:post, topic: pm_topic, user: author, raw: repeated_request)
      first_answer = Fabricate(:post, topic: pm_topic, user: agent.user, raw: "Alpha. " * 2300)
      follow_up = Fabricate(:post, topic: pm_topic, user: author, raw: "More detail please.")
      second_answer = Fabricate(:post, topic: pm_topic, user: agent.user, raw: "Bravo. " * 2300)
      latest_request = Fabricate(:post, topic: pm_topic, user: author, raw: repeated_request)

      canned_response = "Brief summary or answer."
      DiscourseAi::Completions::Llm.with_prepared_responses(
        Array.new(12, canned_response),
      ) do |_, _, prompts, options|
        job.execute(
          post_id: latest_request.id,
          bot_user_id: agent.user_id,
          agent_id: agent.id,
          llm_model_id: gpt_35_bot.id,
          authorization_user_id: author.id,
        )

        reply = pm_topic.posts.order(:post_number).last
        expect(reply.raw).to eq(canned_response)
        expect(reply.user).to eq(agent.user)

        checkpoint = "<compressed_context>#{canned_response}</compressed_context>"
        expect(prompts.last.messages.drop(1)).to match(
          [
            a_hash_including(type: :user, content: checkpoint),
            a_hash_including(type: :model),
            a_hash_including(type: :user, content: latest_request.raw),
          ],
        )

        fragments =
          prompts
            .zip(options)
            .filter_map do |prompt, option|
              next if option[:feature_name] != "context_compression"

              JSON.parse(prompt.messages.last[:content].lines.last).fetch("evidence_fragment")
            end
        evidence = JSON.parse(fragments.join)
        expect(evidence.map { |message| message.values_at("type", "content") }).to eq(
          [
            ["user", repeated_request],
            ["model", first_answer.raw],
            ["user", follow_up.raw],
            ["model", second_answer.raw],
          ],
        )
      end
    end

    it "answers a PM after dropping a system message from stored conversation history" do
      author = Fabricate(:user, refresh_auto_groups: true)
      pm_topic = Fabricate(:private_message_topic, user: author, recipient: agent.user)
      opening = Fabricate(:post, topic: pm_topic, user: author, raw: "Help me plan the garden.")
      historical_reply =
        Fabricate(:post, topic: pm_topic, user: agent.user, raw: "Mint grows well in pots.")
      stored_user_message = "I have a shady balcony."
      private_sentinel = "PRIVATE-PM-HISTORY-QUARTZ-731"
      PostCustomPrompt.create!(
        post: historical_reply,
        custom_prompt: [
          [stored_user_message, author.username, "user"],
          [private_sentinel, nil, "system"],
          [historical_reply.raw, agent.user.username, "model"],
        ],
      )
      latest_request =
        Fabricate(:post, topic: pm_topic, user: author, raw: "What else can I grow there?")

      DiscourseAi::Completions::Llm.with_prepared_responses([expected_response]) do |canned|
        job.execute(
          post_id: latest_request.id,
          bot_user_id: agent.user_id,
          agent_id: agent.id,
          llm_model_id: gpt_35_bot.id,
          authorization_user_id: author.id,
        )

        reply = pm_topic.posts.order(:post_number).last
        expect(reply).to have_attributes(user: agent.user, raw: expected_response)
        expect(canned.completions).to eq(1)
        messages = canned.prompt_messages
        expect(messages.map { |message| message.values_at(:type, :content) }).to match(
          [
            [:system, agent.system_prompt],
            [:user, a_string_including(opening.raw, stored_user_message)],
            [:model, historical_reply.raw],
            [:user, latest_request.raw],
          ],
        )
        expect(messages.to_json).not_to include(private_sentinel)
        expect(
          Array(reply.post_custom_prompt&.custom_prompt).map { |entry| entry[2] },
        ).not_to include("tool_call", "tool")
      end
    end

    it "fails visibly when a member-selected model is no longer selectable at execution" do
      SiteSetting.ai_bot_enabled_llms = ""

      expect do
        job.execute(
          post_id: topic.first_post.id,
          bot_user_id: agent.user_id,
          agent_id: agent.id,
          llm_model_id: gpt_35_bot.id,
          model_selection_source: :request,
          authorization_user_id: topic.first_post.user_id,
        )
      end.to change { topic.posts.count }.by(1)

      expect(topic.posts.last.raw).to include(
        I18n.t("discourse_ai.ai_bot.errors.model_not_selectable"),
      )
      expect(topic.posts.last.user).to eq(agent.user)
    end

    it "fails visibly through an active shared speaker when the queued agent is disabled" do
      speaker = agent.user
      Fabricate(:ai_agent, user: speaker, enabled: true)
      agent.update!(enabled: false)
      expect(speaker.reload).to be_active

      expect do
        job.execute(
          post_id: topic.first_post.id,
          bot_user_id: speaker.id,
          agent_id: agent.id,
          llm_model_id: gpt_35_bot.id,
          authorization_user_id: topic.first_post.user_id,
        )
      end.to change { topic.posts.count }.by(1)

      expect(topic.posts.last.user).to eq(speaker)
      expect(topic.posts.last.raw).to include(I18n.t("discourse_ai.ai_bot.errors.invalid_agent_id"))
    end

    it "fails visibly through the system user when disabling the last agent deactivates its speaker" do
      speaker = agent.user
      agent.update!(enabled: false)
      expect(speaker.reload).not_to be_active

      expect do
        job.execute(
          post_id: topic.first_post.id,
          bot_user_id: speaker.id,
          agent_id: agent.id,
          llm_model_id: gpt_35_bot.id,
          authorization_user_id: topic.first_post.user_id,
        )
      end.to change { topic.posts.count }.by(1)

      error_post = topic.posts.last
      expect(error_post.user).to eq(Discourse.system_user)
      expect(error_post.raw).to include(I18n.t("discourse_ai.ai_bot.errors.invalid_agent_id"))
      expect(error_post.custom_fields).not_to have_key(DiscourseAi::AiBot::POST_AI_AGENT_ID_FIELD)
    end

    it "fails visibly through the system user when the queued agent is deleted" do
      speaker = agent.user
      agent.destroy!

      expect do
        job.execute(
          post_id: topic.first_post.id,
          bot_user_id: speaker.id,
          agent_id: agent.id,
          llm_model_id: gpt_35_bot.id,
          authorization_user_id: topic.first_post.user_id,
        )
      end.to change { topic.posts.count }.by(1)

      expect(topic.posts.last.user).to eq(Discourse.system_user)
      expect(topic.posts.last.raw).to include(I18n.t("discourse_ai.ai_bot.errors.invalid_agent_id"))
      expect(topic.posts.last.custom_fields).not_to have_key(
        DiscourseAi::AiBot::POST_AI_AGENT_ID_FIELD,
      )
    end

    it "does not use a captured legacy model user to author a failure" do
      legacy_model_user = Fabricate(:user, id: ::BotUser.new(DiscourseAi::PLUGIN_NAME).next_id)
      gpt_35_bot.update_column(:user_id, legacy_model_user.id)
      agent.update!(enabled: false)

      expect do
        job.execute(
          post_id: topic.first_post.id,
          bot_user_id: legacy_model_user.id,
          agent_id: agent.id,
          authorization_user_id: topic.first_post.user_id,
        )
      end.to change { topic.posts.count }.by(1)

      expect(topic.posts.last.user).to eq(Discourse.system_user)
      expect(topic.posts.last.user).not_to eq(legacy_model_user)
    end

    it "does not bypass personal-message access for a captured failure speaker" do
      authorization_user = Fabricate(:user, refresh_auto_groups: true)
      pm_topic = Fabricate(:private_message_topic, user: authorization_user, recipient: agent.user)
      prompt_post = Fabricate(:post, topic: pm_topic, user: authorization_user)
      pm_topic.topic_allowed_users.find_by(user_id: agent.user_id).destroy!
      SiteSetting.ai_bot_enabled_llms = ""

      expect do
        job.execute(
          post_id: prompt_post.id,
          bot_user_id: agent.user_id,
          agent_id: agent.id,
          llm_model_id: gpt_35_bot.id,
          model_selection_source: :request,
          authorization_user_id: authorization_user.id,
        )
      end.to change { pm_topic.posts.count }.by(1)

      expect(pm_topic.posts.order(:post_number).last.user).to eq(Discourse.system_user)
    end

    it "preserves an existing AI answer when a retry route fails" do
      reply_post =
        Fabricate(
          :post,
          topic:,
          user: agent.user,
          raw: "Original answer",
          custom_fields: {
            DiscourseAi::AiBot::POST_AI_AGENT_ID_FIELD => agent.id,
            DiscourseAi::AiBot::POST_AI_LLM_NAME_FIELD => gpt_35_bot.display_name,
          },
        )
      SiteSetting.ai_bot_enabled_llms = ""

      expect {
        job.execute(
          post_id: topic.first_post.id,
          reply_post_id: reply_post.id,
          bot_user_id: reply_post.user_id,
          agent_id: agent.id,
          llm_model_id: gpt_35_bot.id,
          model_selection_source: :request,
          authorization_user_id: topic.first_post.user_id,
        )
      }.to change { topic.posts.count }.by(1)

      expect(reply_post.reload.raw).to eq("Original answer")
      expect(topic.posts.order(:post_number).last.raw).to include(
        I18n.t("discourse_ai.ai_bot.errors.model_not_selectable"),
      )
    end

    it "does not reply when an explicit authorization user is missing" do
      expect {
        DiscourseAi::Completions::Llm.with_prepared_responses([expected_response]) do
          job.execute(
            post_id: topic.first_post.id,
            bot_user_id: agent.user_id,
            agent_id: agent.id,
            llm_model_id: gpt_35_bot.id,
            authorization_user_id: nil,
          )
        end
      }.not_to change { topic.posts.count }
    end

    it "does not revise an arbitrary human post from a stale job" do
      human_reply = Fabricate(:post, topic:, user: Fabricate(:user), raw: "Human answer")

      expect {
        job.execute(
          post_id: topic.first_post.id,
          reply_post_id: human_reply.id,
          agent_id: agent.id,
          llm_model_id: gpt_35_bot.id,
          authorization_user_id: topic.first_post.user_id,
        )
      }.not_to change { topic.posts.count }

      expect(human_reply.reload.raw).to eq("Human answer")
    end

    it "does not use an inaccessible requested agent to author a routing error" do
      agent.update!(allowed_group_ids: [Group::AUTO_GROUPS[:staff]])

      expect do
        job.execute(
          post_id: topic.first_post.id,
          agent_id: agent.id,
          llm_model_id: gpt_35_bot.id,
          authorization_user_id: topic.first_post.user_id,
        )
      end.to change { topic.posts.count }.by(1)

      expect(topic.posts.last.user).to eq(Discourse.system_user)
      expect(topic.posts.last.custom_fields).not_to have_key(
        DiscourseAi::AiBot::POST_AI_AGENT_ID_FIELD,
      )
    end

    it "normalizes a legacy payload using the post author and agent default" do
      DiscourseAi::Completions::Llm.with_prepared_responses([expected_response]) do
        job.execute(post_id: topic.first_post.id, bot_user_id: agent.user_id, agent_id: agent.id)
      end

      expect(topic.posts.last.raw).to eq(expected_response)
      expect(topic.posts.last.user).to eq(agent.user)
    end

    it "records authorization provenance before streaming generation fails" do
      authorization_user = Fabricate(:user, refresh_auto_groups: true)
      pm_topic = Fabricate(:private_message_topic, user: authorization_user, recipient: agent.user)
      pm_topic.custom_fields[DiscourseAi::AiBot::TOPIC_AI_AGENT_ID_FIELD] = agent.id
      pm_topic.custom_fields[DiscourseAi::AiBot::TOPIC_AI_LLM_MODEL_ID_FIELD] = gpt_35_bot.id
      pm_topic.save_custom_fields
      prompt_post = Fabricate(:post, topic: pm_topic, user: authorization_user)

      expect {
        DiscourseAi::Completions::Llm.with_prepared_responses([]) do
          job.execute(
            post_id: prompt_post.id,
            bot_user_id: agent.user_id,
            agent_id: agent.id,
            llm_model_id: gpt_35_bot.id,
            authorization_user_id: authorization_user.id,
          )
        end
      }.to raise_error(DiscourseAi::Completions::Endpoints::CannedResponse::CANNED_RESPONSE_ERROR)

      bot_reply = pm_topic.posts.order(:post_number).last
      expect(
        bot_reply.custom_fields[DiscourseAi::AiBot::POST_AI_AGENT_AUTHORIZATION_USER_ID_FIELD].to_i,
      ).to eq(authorization_user.id)
    end
  end
end
