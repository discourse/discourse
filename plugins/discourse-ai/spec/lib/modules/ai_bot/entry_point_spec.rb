# frozen_string_literal: true

describe DiscourseAi::AiBot::EntryPoint do
  before { enable_current_plugin }

  describe "#inject_into" do
    describe "subscribes to the post_created event" do
      fab!(:admin)
      fab!(:bot_allowed_group, :group)
      fab!(:gpt_4) { Fabricate(:llm_model, name: "gpt-4") }
      fab!(:claude_2) { Fabricate(:llm_model, name: "claude-2") }
      fab!(:agent) do
        Fabricate(
          :ai_agent,
          enabled: true,
          allowed_group_ids: [bot_allowed_group.id],
          allow_personal_messages: true,
          default_llm: gpt_4,
        ).tap(&:ensure_user!)
      end

      let(:post_args) do
        {
          title: "Dear AI, I want to ask a question",
          raw: "Hello, Can you please tell me a story?",
          archetype: Archetype.private_message,
          target_usernames: agent.user.username,
          topic_opts: {
            custom_fields: {
              DiscourseAi::AiBot::TOPIC_AI_AGENT_ID_FIELD => agent.id,
              DiscourseAi::AiBot::TOPIC_AI_LLM_MODEL_ID_FIELD => gpt_4.id,
            },
          },
        }
      end

      before do
        toggle_enabled_bots(bots: [gpt_4, claude_2])
        SiteSetting.ai_bot_enabled = true
        SiteSetting.ai_bot_allowed_groups = bot_allowed_group.id
        bot_allowed_group.add(admin)
      end

      it "adds a can_debug_ai_bot_conversations method to current user" do
        SiteSetting.ai_bot_debugging_allowed_groups = bot_allowed_group.id.to_s
        serializer = CurrentUserSerializer.new(admin, scope: Guardian.new(admin)).as_json

        expect(serializer[:current_user][:can_debug_ai_bot_conversations]).to eq(true)
      end

      it "marks a personal message with one agent recipient as an AI conversation" do
        topic = PostCreator.create!(admin, post_args).topic

        expect(topic.reload.custom_fields[DiscourseAi::AiBot::TOPIC_AI_BOT_PM_FIELD]).to eq("t")
      end

      it "does not mark a personal message that includes another person" do
        user = Fabricate(:user)
        post_args[:target_usernames] = [agent.user.username, user.username].join(",")
        topic = PostCreator.create!(admin, post_args).topic

        expect(topic.reload.custom_fields[DiscourseAi::AiBot::TOPIC_AI_BOT_PM_FIELD]).to be_nil
      end

      it "serializes agents and selectable models independently" do
        serializer = CurrentUserSerializer.new(admin, scope: Guardian.new(admin)).as_json
        current_user_json = serializer[:current_user]

        serialized_agent =
          current_user_json[:ai_enabled_agents].find { |item| item[:id] == agent.id }
        serialized_model =
          current_user_json[:ai_available_llm_models].find { |item| item["id"] == gpt_4.id }

        expect(serialized_agent).to include(
          username: agent.user.username_lower,
          default_llm_id: gpt_4.id,
          force_default_llm: false,
        )
        expect(serialized_model).to include(
          "display_name" => gpt_4.display_name,
          "model_name" => gpt_4.name,
        )
        expect(serialized_model).not_to have_key("username")
      end

      it "adds forced-model information to the agent payload" do
        agent.update!(default_llm: claude_2, force_default_llm: true)

        serializer = CurrentUserSerializer.new(admin, scope: Guardian.new(admin)).as_json
        serialized_agent =
          serializer[:current_user][:ai_enabled_agents].find { |item| item[:id] == agent.id }

        expect(serialized_agent).to include(
          default_llm_id: claude_2.id,
          default_llm_name: claude_2.display_name,
          force_default_llm: true,
        )
      end

      it "queues a model snapshot using the agent speaker" do
        expect { PostCreator.create!(admin, post_args) }.to change(
          Jobs::CreateAiReply.jobs,
          :size,
        ).by(1)

        job_args = Jobs::CreateAiReply.jobs.last["args"].first
        expect(job_args).to include(
          "bot_user_id" => agent.user_id,
          "agent_id" => agent.id,
          "llm_model_id" => gpt_4.id,
          "authorization_user_id" => admin.id,
        )
      end

      it "does not queue a job for small actions" do
        post = PostCreator.create!(admin, post_args)

        %i[small_action moderator_action whisper].each do |post_type|
          expect {
            post.topic.add_moderator_post(
              admin,
              "this is a small action",
              post_type: Post.types[post_type],
            )
          }.not_to change(Jobs::CreateAiReply.jobs, :size)
        end
      end

      it "does not queue a reply outside a personal message without an agent mention" do
        expect {
          PostCreator.create!(
            admin,
            post_args.except(:topic_opts, :target_usernames).merge(archetype: Archetype.default),
          )
        }.not_to change(Jobs::CreateAiReply.jobs, :size)
      end

      it "does not queue when the target is not an AI agent" do
        user = Fabricate(:user)

        expect {
          PostCreator.create!(
            admin,
            post_args.except(:topic_opts).merge(target_usernames: user.username),
          )
        }.not_to change(Jobs::CreateAiReply.jobs, :size)
      end

      it "does not queue when the author cannot use the agent" do
        bot_allowed_group.remove(admin)

        expect { PostCreator.create(admin, post_args) }.not_to change(
          Jobs::CreateAiReply.jobs,
          :size,
        )
      end

      it "does not queue a response to the agent's own post" do
        topic_id = PostCreator.create!(admin, post_args).topic_id
        reply_args =
          post_args.except(:archetype, :target_usernames, :title, :topic_opts).merge(
            topic_id: topic_id,
          )

        expect { PostCreator.create!(agent.user, reply_args) }.not_to change(
          Jobs::CreateAiReply.jobs,
          :size,
        )
      end
    end

    it "includes ai_search_discoveries in user_option if the discover agent is enabled" do
      user = Fabricate(:user)
      group = Fabricate(:group)
      group.add(user)
      llm_model = Fabricate(:llm_model)
      agent = Fabricate(:ai_agent, allowed_group_ids: [group.id], default_llm_id: llm_model.id)
      enable_legacy_discover
      SiteSetting.ai_discover_agent = agent.id
      SiteSetting.ai_embeddings_enabled = true
      SiteSetting.ai_embeddings_semantic_search_enabled = true
      user.user_option.update!(ai_search_discoveries: true)
      serializer = CurrentUserSerializer.new(user, scope: Guardian.new(user)).as_json

      expect(serializer[:current_user][:user_option]).to include(ai_search_discoveries: true)
    end

    it "allows Ask AI independently of the deprecated Discoveries preference" do
      user = Fabricate(:user)
      group = Fabricate(:group)
      group.add(user)
      llm_model = Fabricate(:llm_model)
      agent = Fabricate(:ai_agent, allowed_group_ids: [group.id], default_llm_id: llm_model.id)
      SiteSetting.ai_ask_ai_enabled = true
      SiteSetting.ai_ask_ai_agent = agent.id
      SiteSetting.ai_ask_ai_allowed_groups = group.id.to_s
      SiteSetting.ai_embeddings_enabled = true
      SiteSetting.ai_embeddings_semantic_search_enabled = true
      user.user_option.update!(ai_search_discoveries: false)

      serializer = CurrentUserSerializer.new(user, scope: Guardian.new(user)).as_json

      expect(serializer[:current_user]).to include(can_use_ask_ai: true)
    end
  end
end
