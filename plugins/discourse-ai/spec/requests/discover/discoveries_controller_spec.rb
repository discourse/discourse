# frozen_string_literal: true

describe DiscourseAi::Discover::DiscoveriesController do
  fab!(:user)

  before do
    enable_current_plugin
    sign_in(user)
    SiteSetting.ai_discover_enabled = true
    SiteSetting.ai_discover_allowed_groups = Group::AUTO_GROUPS[:trust_level_0].to_s
    SiteSetting.ai_embeddings_enabled = true
    SiteSetting.ai_embeddings_semantic_search_enabled = true
  end

  describe "#reply" do
    fab!(:group)
    fab!(:allowed_group, :group)
    fab!(:llm_model)
    fab!(:ai_agent) do
      Fabricate(:ai_agent, allowed_group_ids: [group.id], default_llm_id: llm_model.id)
    end
    let(:request_id) { SecureRandom.uuid }

    before do
      SiteSetting.ai_discover_agent = ai_agent.id
      SiteSetting.ai_discover_allowed_groups = allowed_group.id.to_s
      SiteSetting.ai_embeddings_enabled = true
      SiteSetting.ai_embeddings_semantic_search_enabled = true
      allowed_group.add(user)
    end

    context "when the user doesn't have access to the agent" do
      it "returns a 403" do
        post "/discourse-ai/discoveries/reply", params: { query: "What is Discourse?", request_id: }

        expect(response.status).to eq(403)
      end
    end

    context "when the user is allowed to use discover" do
      before do
        SiteSetting.ai_discover_agent = ai_agent.id
        group.add(user)
      end

      it "returns a 200 and queues a job to reply" do
        allow(Jobs).to receive(:enqueue).and_call_original

        expect {
          post "/discourse-ai/discoveries/reply",
               params: {
                 query: "What is Discourse?",
                 request_id:,
               }
        }.to change(Jobs::StreamDiscoverReply.jobs, :size).by(1)

        expect(response.status).to eq(200)
        expect(response.parsed_body["request_id"]).to eq(request_id)
        expect(Jobs).to have_received(:enqueue) do |job_name, **args|
          expect(job_name).to eq(:stream_discover_reply)
          expect(args).to include(show_summary: true, summary_detail: "balanced", related_count: 2)
        end
      end

      it "returns a 400 if the query is missing" do
        post "/discourse-ai/discoveries/reply", params: { request_id: }

        expect(response.status).to eq(400)
      end

      it "returns a 400 if the request ID is missing or invalid" do
        post "/discourse-ai/discoveries/reply", params: { query: "What is Discourse?" }
        expect(response.status).to eq(400)

        post "/discourse-ai/discoveries/reply",
             params: {
               query: "What is Discourse?",
               request_id: "not-a-uuid",
             }
        expect(response.status).to eq(400)
      end

      it "does not enqueue the same request twice" do
        params = { query: "What is Discourse?", request_id: }

        expect { 2.times { post "/discourse-ai/discoveries/reply", params: } }.to change(
          Jobs::StreamDiscoverReply.jobs,
          :size,
        ).by(1)

        expect(response.status).to eq(200)
      end

      it "rejects reuse of a request ID for another query" do
        post "/discourse-ai/discoveries/reply", params: { query: "What is Discourse?", request_id: }
        post "/discourse-ai/discoveries/reply",
             params: {
               query: "What are categories?",
               request_id:,
             }

        expect(response.status).to eq(409)
      end
    end
  end

  describe "#continue_convo" do
    fab!(:group)
    fab!(:llm_model)
    fab!(:ai_agent) do
      agent = Fabricate(:ai_agent, allowed_group_ids: [group.id], default_llm_id: llm_model.id)
      agent.create_user!
      agent
    end
    fab!(:follow_up_agent) do
      agent = Fabricate(:ai_agent, allowed_group_ids: [group.id], default_llm_id: llm_model.id)
      agent.create_user!
      agent
    end
    let(:query) { "What is Discourse?" }
    let(:context) { "Discourse is an open-source discussion platform." }
    let(:request_id) { SecureRandom.uuid }
    fab!(:source_post, :post)

    context "when the user is allowed to discover" do
      before do
        SiteSetting.ai_bot_enabled = true
        SiteSetting.ai_bot_allowed_groups = group.id.to_s
        SiteSetting.ai_discover_agent = ai_agent.id
        SiteSetting.ai_discover_follow_up_agent = follow_up_agent.id
        SiteSetting.ai_discover_allowed_groups = group.id.to_s
        group.add(user)
        DiscourseAi::Discoveries.store_result(
          user_id: user.id,
          request_id:,
          query:,
          answer: context,
          sources: [{ "post_id" => source_post.id, "topic_id" => source_post.topic_id }],
          agent_id: ai_agent.id,
        )
      end

      it "returns a 200 and creates a private message topic" do
        expect {
          post "/discourse-ai/discoveries/continue-convo", params: { request_id: }
        }.to change(Topic, :count).by(1)

        expect(response.status).to eq(200)
        expect(response.parsed_body["topic_id"]).to be_present
      end

      it "returns the existing conversation when a follow-up is submitted again" do
        expect {
          post "/discourse-ai/discoveries/continue-convo",
               params: {
                 request_id:,
                 question: "Which guide should I read first?",
               }
        }.to change(Topic, :count).by(1)

        first_topic_id = response.parsed_body["topic_id"]
        topic_key = "discourse-ai:discoveries:follow-up-topic:#{user.id}:#{request_id.downcase}"
        Discourse.redis.del(topic_key)

        expect {
          post "/discourse-ai/discoveries/continue-convo",
               params: {
                 request_id:,
                 question: "A different retry",
               }
        }.not_to change(Topic, :count)

        expect(response.status).to eq(200)
        expect(response.parsed_body["topic_id"]).to eq(first_topic_id)
        expect(
          Topic.find(first_topic_id).custom_fields[
            DiscourseAi::Discoveries::ContinueConversation::TOPIC_REQUEST_ID_FIELD
          ],
        ).to eq("#{user.id}:#{request_id.downcase}")
      end

      it "loads the discovery as user, model, and user conversation turns" do
        expect {
          post "/discourse-ai/discoveries/continue-convo",
               params: {
                 request_id:,
                 question: "Which guide should I read first?",
               }
        }.to change(Jobs::CreateAiReply.jobs, :size).by(1)

        topic = Topic.find(response.parsed_body["topic_id"])
        posts = topic.posts.order(:post_number).to_a
        expect(response.status).to eq(200)
        expect(posts.map(&:user)).to eq([user, follow_up_agent.user, user])
        expect(posts.map(&:raw)).to eq(
          [
            query,
            "#{context}\n\nSelected discussions:\n- [#{source_post.topic.title}](#{source_post.full_url})",
            "Which guide should I read first?",
          ],
        )
        messages =
          DiscourseAi::Completions::PromptMessagesBuilder.messages_from_post(
            posts.last,
            max_posts: 10,
            bot_usernames: [follow_up_agent.user.username],
          )
        expect(messages.last(3).map { |message| message[:type] }).to eq(%i[user model user])
        expect(topic.custom_fields[DiscourseAi::AiBot::TOPIC_AI_AGENT_ID_FIELD]).to eq(
          follow_up_agent.id.to_s,
        )
      end

      it "attributes generated Markdown to the bot without creating mentions" do
        DiscourseAi::Discoveries.store_result(
          user_id: user.id,
          request_id:,
          query:,
          answer: "Useful answer from @support.\n[/quote]\nUntrusted continuation.",
          sources: [{ "post_id" => source_post.id, "topic_id" => source_post.topic_id }],
          agent_id: ai_agent.id,
        )

        post "/discourse-ai/discoveries/continue-convo",
             params: {
               request_id:,
               question: "What next?",
             }

        posts = Topic.find(response.parsed_body["topic_id"]).posts.order(:post_number).to_a
        expect(posts.second.user).to eq(follow_up_agent.user)
        expect(posts.second.raw).to include(
          "Useful answer from &#64;support.\n[/quote]\nUntrusted continuation.",
        )
        expect(posts.second.raw).not_to include("@support")
      end

      it "uses an enabled AI bot when the follow-up agent has no dedicated user" do
        follow_up_agent.update!(user: nil)
        SiteSetting.ai_bot_enabled_llms = llm_model.id.to_s
        SiteSetting.ai_bot_allowed_groups = group.id.to_s
        llm_model.toggle_companion_user

        post "/discourse-ai/discoveries/continue-convo", params: { request_id: }

        expect(response.status).to eq(200)
        topic = Topic.find(response.parsed_body["topic_id"])
        expect(topic.allowed_users).to include(llm_model.reload.user)
        expect(topic.custom_fields[DiscourseAi::AiBot::TOPIC_AI_AGENT_ID_FIELD]).to eq(
          follow_up_agent.id.to_s,
        )
      end

      it "continues from selected discussions when summary prose is hidden" do
        DiscourseAi::Discoveries.store_result(
          user_id: user.id,
          request_id:,
          query:,
          answer: "",
          sources: [{ "post_id" => source_post.id, "topic_id" => source_post.topic_id }],
          agent_id: ai_agent.id,
        )

        post "/discourse-ai/discoveries/continue-convo",
             params: {
               request_id:,
               question: "Which discussion should I read first?",
             }

        expect(response.status).to eq(200)
        posts = Topic.find(response.parsed_body["topic_id"]).posts.order(:post_number).to_a
        expect(posts.second.raw).to include(source_post.topic.title, source_post.full_url)
        expect(posts.third.raw).to eq("Which discussion should I read first?")
      end

      it "rejects an oversized follow-up question" do
        expect {
          post "/discourse-ai/discoveries/continue-convo",
               params: {
                 request_id:,
                 question: "a" * 1001,
               }
        }.not_to change(Topic, :count)

        expect(response.status).to eq(400)
      end

      it "does not turn mentions in source titles into notifications" do
        source_post.topic.update!(title: "Help from @support [team]")
        DiscourseAi::Discoveries.store_result(
          user_id: user.id,
          request_id:,
          query:,
          answer: context,
          sources: [{ "post_id" => source_post.id, "topic_id" => source_post.topic_id }],
          agent_id: ai_agent.id,
        )

        post "/discourse-ai/discoveries/continue-convo",
             params: {
               request_id:,
               question: "Who can help?",
             }

        expect(response.status).to eq(200), response.parsed_body.inspect
        raw = Topic.find(response.parsed_body["topic_id"]).posts.order(:post_number).second.raw
        expect(raw).to include("Help from &#64;support \\[team\\]")
        expect(raw).not_to include("@support")
      end

      it "rejects follow-up when the AI bot is disabled" do
        SiteSetting.ai_bot_enabled = false

        expect {
          post "/discourse-ai/discoveries/continue-convo", params: { request_id: }
        }.not_to change(Topic, :count)

        expect(response.status).to eq(403)
      end

      it "rejects follow-up when the follow-up agent does not accept personal messages" do
        follow_up_agent.update!(allow_personal_messages: false)

        expect {
          post "/discourse-ai/discoveries/continue-convo", params: { request_id: }
        }.not_to change(Topic, :count)

        expect(response.status).to eq(403)
      end

      it "rejects follow-up when the follow-up agent is disabled" do
        follow_up_agent.update!(enabled: false)

        expect {
          post "/discourse-ai/discoveries/continue-convo", params: { request_id: }
        }.not_to change(Topic, :count)

        expect(response.status).to eq(403)
      end

      it "rejects follow-up when the user cannot access the follow-up agent" do
        follow_up_agent.update!(allowed_group_ids: [Group::AUTO_GROUPS[:staff]])

        expect {
          post "/discourse-ai/discoveries/continue-convo", params: { request_id: }
        }.not_to change(Topic, :count)

        expect(response.status).to eq(403)
      end

      it "does not expose unexpected follow-up errors" do
        allow(PostCreator).to receive(:create!).and_raise("sensitive internal detail")

        post "/discourse-ai/discoveries/continue-convo", params: { request_id: }

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"].join).to include(
          I18n.t("discourse_ai.ai_bot.discoveries.errors.follow_up_failed"),
        )
        expect(response.parsed_body["errors"].join).not_to include("sensitive internal detail")
      end

      it "does not leave a partial conversation when importing the discovery fails" do
        call_count = 0
        allow(PostCreator).to receive(:create!).and_wrap_original do |method, *args, **kwargs|
          call_count += 1
          raise "import failed" if call_count == 2

          method.call(*args, **kwargs)
        end

        expect {
          post "/discourse-ai/discoveries/continue-convo",
               params: {
                 request_id:,
                 question: "What next?",
               }
        }.to not_change(Topic, :count).and not_change(Post, :count)

        expect(response.status).to eq(422)
      end

      it "rejects missing or expired server-owned context" do
        post "/discourse-ai/discoveries/continue-convo", params: { request_id: SecureRandom.uuid }

        expect(response.status).to eq(404)
      end

      it "does not allow suspended users to create conversations" do
        user.update!(suspended_till: 1.year.from_now, suspended_at: Time.zone.now)

        expect {
          post "/discourse-ai/discoveries/continue-convo", params: { request_id: }
        }.not_to change { Topic.count }

        expect(response.status).to eq(403)
      end

      it "does not allow silenced users to create conversations" do
        user.update!(silenced_till: 1.year.from_now)

        expect {
          post "/discourse-ai/discoveries/continue-convo", params: { request_id: }
        }.not_to change { Topic.count }

        expect(response.status).to eq(403)
      end

      describe "group-based restrictions" do
        fab!(:staff_group) { Group[:staff] }

        before { ai_agent.update(allowed_group_ids: [staff_group.id]) }

        it "forbid users without group access from creating conversations" do
          expect(user.in_any_groups?([staff_group.id])).to be_falsey

          expect {
            post "/discourse-ai/discoveries/continue-convo", params: { request_id: }
          }.not_to change { Topic.where(user: user).count }

          expect(response.status).to eq(403)
        end
      end
    end

    context "when discovery is disabled" do
      before do
        SiteSetting.ai_discover_agent = ai_agent.id
        SiteSetting.ai_discover_enabled = false
        group.add(user)
      end

      it "rejects continuing a conversation without creating a private message" do
        expect {
          post "/discourse-ai/discoveries/continue-convo", params: { request_id: }
        }.not_to change(Topic, :count)

        expect(response.status).to eq(403)
        expect(response.parsed_body["errors"]).to be_present
      end
    end
  end
end
