# frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::EntryPoint do
  before { enable_current_plugin }

  describe "#inject_into" do
    describe "subscribes to the post_created event" do
      fab!(:admin)
      fab!(:bot_allowed_group) { Fabricate(:group) }

      fab!(:gpt_4) { Fabricate(:llm_model, name: "gpt-4") }
      let(:gpt_bot) { gpt_4.reload.user }

      fab!(:claude_2) { Fabricate(:llm_model, name: "claude-2") }

      let(:post_args) do
        {
          title: "Dear AI, I want to ask a question",
          raw: "Hello, Can you please tell me a story?",
          archetype: Archetype.private_message,
          target_usernames: [gpt_bot.username].join(","),
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
        serializer = CurrentUserSerializer.new(admin, scope: Guardian.new(admin))
        serializer = serializer.as_json

        expect(serializer[:current_user][:can_debug_ai_bot_conversations]).to eq(true)
      end

      describe "adding TOPIC_AI_BOT_PM_FIELD to topic custom fields" do
        it "is added when user PMs a single bot" do
          topic = PostCreator.create!(admin, post_args).topic
          expect(topic.reload.custom_fields[DiscourseAi::AiBot::TOPIC_AI_BOT_PM_FIELD]).to eq("t")
        end

        it "is not added when user PMs a bot and another user" do
          user = Fabricate(:user)
          post_args[:target_usernames] = [gpt_bot.username, user.username].join(",")
          topic = PostCreator.create!(admin, post_args).topic
          expect(topic.reload.custom_fields[DiscourseAi::AiBot::TOPIC_AI_BOT_PM_FIELD]).to be_nil
        end
      end

      it "adds information about forcing default llm to current_user_serializer" do
        Group.refresh_automatic_groups!

        persona =
          Fabricate(
            :ai_persona,
            enabled: true,
            allowed_group_ids: [bot_allowed_group.id],
            default_llm_id: claude_2.id,
            force_default_llm: true,
          )
        persona.create_user!

        serializer = CurrentUserSerializer.new(admin, scope: Guardian.new(admin))
        serializer = serializer.as_json
        bots = serializer[:current_user][:ai_enabled_chat_bots]

        persona_bot = bots.find { |bot| bot["id"] == persona.user_id }

        expect(persona_bot["username"]).to eq(persona.user.username)
        expect(persona_bot["force_default_llm"]).to eq(true)
      end

      it "includes user ids for all personas in the serializer" do
        Group.refresh_automatic_groups!

        persona = Fabricate(:ai_persona, enabled: true, allowed_group_ids: [bot_allowed_group.id])
        persona.create_user!

        serializer = CurrentUserSerializer.new(admin, scope: Guardian.new(admin))
        serializer = serializer.as_json
        bots = serializer[:current_user][:ai_enabled_chat_bots]

        persona_bot = bots.find { |bot| bot["id"] == persona.user_id }
        expect(persona_bot["username"]).to eq(persona.user.username)
        expect(persona_bot["force_default_llm"]).to eq(false)
      end

      it "queues a job to generate a reply by the AI" do
        expect { PostCreator.create!(admin, post_args) }.to change(
          Jobs::CreateAiReply.jobs,
          :size,
        ).by(1)
      end

      it "does not queue a job for small actions" do
        post = PostCreator.create!(admin, post_args)

        expect {
          post.topic.add_moderator_post(
            admin,
            "this is a small action",
            post_type: Post.types[:small_action],
          )
        }.not_to change(Jobs::CreateAiReply.jobs, :size)

        expect {
          post.topic.add_moderator_post(
            admin,
            "this is a small action",
            post_type: Post.types[:moderator_action],
          )
        }.not_to change(Jobs::CreateAiReply.jobs, :size)

        expect {
          post.topic.add_moderator_post(
            admin,
            "this is a small action",
            post_type: Post.types[:whisper],
          )
        }.not_to change(Jobs::CreateAiReply.jobs, :size)
      end

      it "includes the bot's user_id" do
        claude_bot = DiscourseAi::AiBot::EntryPoint.find_user_from_model("claude-2")
        claude_post_attrs = post_args.merge(target_usernames: [claude_bot.username].join(","))

        expect { PostCreator.create!(admin, claude_post_attrs) }.to change(
          Jobs::CreateAiReply.jobs,
          :size,
        ).by(1)

        job_args = Jobs::CreateAiReply.jobs.last["args"].first
        expect(job_args["bot_user_id"]).to eq(claude_bot.id)
      end

      context "when the post is not from a PM" do
        it "does nothing" do
          expect {
            PostCreator.create!(admin, post_args.merge(archetype: Archetype.default))
          }.not_to change(Jobs::CreateAiReply.jobs, :size)
        end
      end

      context "when the bot doesn't have access to the PM" do
        it "does nothing" do
          user_2 = Fabricate(:user)
          expect {
            PostCreator.create!(admin, post_args.merge(target_usernames: [user_2.username]))
          }.not_to change(Jobs::CreateAiReply.jobs, :size)
        end
      end

      context "when the user is not allowed to interact with the bot" do
        it "does nothing" do
          bot_allowed_group.remove(admin)
          expect { PostCreator.create!(admin, post_args) }.not_to change(
            Jobs::CreateAiReply.jobs,
            :size,
          )
        end
      end

      context "when the post was created by the bot" do
        it "does nothing" do
          gpt_topic_id = PostCreator.create!(admin, post_args).topic_id
          reply_args =
            post_args.except(:archetype, :target_usernames, :title).merge(topic_id: gpt_topic_id)

          expect { PostCreator.create!(gpt_bot, reply_args) }.not_to change(
            Jobs::CreateAiReply.jobs,
            :size,
          )
        end
      end
    end

    it "will include ai_search_discoveries field in the user_option if discover persona is enabled" do
      SiteSetting.ai_bot_enabled = true
      SiteSetting.ai_discover_persona = Fabricate(:ai_persona).id

      serializer =
        CurrentUserSerializer.new(Fabricate(:user), scope: Guardian.new(Fabricate(:user)))
      expect(serializer.user_option.ai_search_discoveries).to eq(true)
    end
  end
end
