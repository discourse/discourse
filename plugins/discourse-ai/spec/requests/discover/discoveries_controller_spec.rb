# frozen_string_literal: true

describe DiscourseAi::Discover::DiscoveriesController do
  fab!(:user)

  before do
    enable_current_plugin
    sign_in(user)
    SiteSetting.ai_ask_ai_enabled = true
    SiteSetting.ai_ask_ai_allowed_groups = Group::AUTO_GROUPS[:trust_level_0].to_s
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
      SiteSetting.ai_ask_ai_agent = ai_agent.id
      SiteSetting.ai_ask_ai_allowed_groups = allowed_group.id.to_s
      SiteSetting.ai_embeddings_enabled = true
      SiteSetting.ai_embeddings_semantic_search_enabled = true
      allowed_group.add(user)
    end

    it "queues an Ask AI reply when embeddings and semantic search are disabled" do
      group.add(user)
      SiteSetting.ai_embeddings_enabled = false
      SiteSetting.ai_embeddings_semantic_search_enabled = false

      expect_enqueued_with(job: :stream_discover_reply, args: { user_id: user.id, request_id: }) do
        post "/discourse-ai/discoveries/reply", params: { query: "What is Discourse?", request_id: }
      end

      expect(response.status).to eq(200)
      expect(response.parsed_body["request_id"]).to eq(request_id)
    end

    context "when the user doesn't have access to the agent" do
      it "returns a 403" do
        post "/discourse-ai/discoveries/reply", params: { query: "What is Discourse?", request_id: }

        expect(response.status).to eq(403)
        expect(AskAiLog.count).to eq(0)
      end
    end

    context "when the user is allowed to use discover" do
      before do
        SiteSetting.ai_ask_ai_agent = ai_agent.id
        group.add(user)
      end

      it "passes the scope the question was asked from to the job" do
        expect_enqueued_with(
          job: :stream_discover_reply,
          args: {
            user_id: user.id,
            request_id:,
            scope: "category:12",
          },
        ) do
          post "/discourse-ai/discoveries/reply",
               params: {
                 query: "What is Discourse?",
                 request_id:,
                 scope: "category:12",
               }
        end

        expect(response.status).to eq(200)
      end

      it "records what set off the request" do
        post "/discourse-ai/discoveries/reply",
             params: {
               query: "What is Discourse?",
               request_id:,
               trigger: "pause",
               trigger_reason: "after_skip:places",
             }

        expect(response.status).to eq(200)
        expect(AskAiLog.last).to have_attributes(
          ask_trigger: "pause",
          ask_trigger_reason: "after_skip:places",
        )
      end

      it "ignores a trigger it does not know rather than failing the request" do
        post "/discourse-ai/discoveries/reply",
             params: {
               query: "What is Discourse?",
               request_id:,
               trigger: "telepathy",
               trigger_reason: "<script>",
             }

        expect(response.status).to eq(200)
        expect(AskAiLog.last).to have_attributes(ask_trigger: "", ask_trigger_reason: "")
      end

      it "rejects a scope that is not one" do
        post "/discourse-ai/discoveries/reply",
             params: {
               query: "What is Discourse?",
               request_id:,
               scope: "category:12 in:all",
             }

        expect(response.status).to eq(400)
      end

      it "returns a 200 and queues a job to reply" do
        SiteSetting.ai_ask_ai_summary_detail = "detailed"
        SiteSetting.ai_ask_ai_related_count = 5
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
          expect(args).to include(summary_detail: "detailed", related_count: 5)
        end
      end

      it "logs each accepted ask once without consolidating repeated questions" do
        query = "How do I search for 猫?"
        params = { query:, request_id: }

        expect {
          2.times { post "/discourse-ai/discoveries/reply", params: }
          post "/discourse-ai/discoveries/reply", params: { query:, request_id: SecureRandom.uuid }
        }.to change(AskAiLog, :count).by(2)

        logs = AskAiLog.order(:id).last(2)
        expect(logs).to all(have_attributes(user_id: user.id, query:, ask_outcome: nil))
        expect(logs.map(&:asked_at)).to all(be_present)
        expect(
          Jobs::StreamDiscoverReply.jobs.last(2).map { |job| job["args"].first["ask_ai_log_id"] },
        ).to eq(logs.map(&:id))
      end

      it "returns a 400 if the query is missing" do
        post "/discourse-ai/discoveries/reply", params: { request_id: }

        expect(response.status).to eq(400)
        expect(AskAiLog.count).to eq(0)
      end

      it "returns a 400 if the request ID is invalid" do
        post "/discourse-ai/discoveries/reply",
             params: {
               query: "What is Discourse?",
               request_id: "not-a-uuid",
             }
        expect(response.status).to eq(400)
        expect(AskAiLog.count).to eq(0)
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

  describe "#reply with deprecated Discover" do
    fab!(:group)
    fab!(:llm_model)
    fab!(:ai_agent) do
      Fabricate(:ai_agent, allowed_group_ids: [group.id], default_llm_id: llm_model.id)
    end

    before do
      enable_legacy_discover
      SiteSetting.ai_discover_agent = ai_agent.id
      group.add(user)
    end

    it "queues an answer using the original Discover feature" do
      allow(Jobs).to receive(:enqueue).and_call_original

      expect {
        post "/discourse-ai/discoveries/reply", params: { query: "What is Discourse?" }
      }.to change(Jobs::StreamDiscoverReply.jobs, :size).by(1)

      expect(response.status).to eq(200)
      expect(Jobs).to have_received(:enqueue).with(
        :stream_discover_reply,
        user_id: user.id,
        query: "What is Discourse?",
      )
    end
  end

  describe "#reply with search intent" do
    fab!(:decision_model)
    fab!(:llm_model)
    fab!(:ai_agent) do
      Fabricate(
        :ai_agent,
        allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
        default_llm_id: llm_model.id,
      )
    end
    let(:request_id) { SecureRandom.uuid }

    before do
      Group.refresh_automatic_groups!
      SiteSetting.ai_ask_ai_agent = ai_agent.id
      SiteSetting.ai_ask_ai_search_intent_decision_model = decision_model.id
      SiteSetting.enable_ai_combined_search = true
    end

    it "returns the decision model's judgement and logs it beside the heuristic's" do
      DiscourseAi::Decisions.with_canned_answers(intent: { "answer" => 0.3, "lookup" => 0.7 }) do
        post "/discourse-ai/discoveries/reply",
             params: {
               query: "password reset",
               request_id:,
               intent_heuristic: "answer",
               classify_intent: true,
             }
      end

      expect(response.status).to eq(200)
      expect(response.parsed_body["intent"]).to eq("intent" => "lookup", "probability" => 0.7)
      expect(response.parsed_body["ask_log_id"]).to eq(AskAiLog.last.id)
      expect(AskAiLog.last).to have_attributes(
        ask_intent_heuristic: "answer",
        ask_intent_model: "lookup",
        ask_intent_probability: 0.7,
      )
    end

    it "answers a scoped search from the whole site when the model says it is about the site" do
      topic = Fabricate(:topic, title: "Upgrading to PostgreSQL 18")

      DiscourseAi::Decisions.with_canned_answers(
        intent: "answer",
        scope: {
          "here" => 0.1,
          "site" => 0.9,
        },
      ) do
        expect_enqueued_with(job: :stream_discover_reply, args: { scope: nil }) do
          post "/discourse-ai/discoveries/reply",
               params: {
                 query: "install discourse",
                 request_id:,
                 scope: "topic:#{topic.id}",
                 classify_intent: true,
               }
        end
      end

      expect(response.parsed_body["intent"]).to include(
        "scope" => "site",
        "scope_probability" => 0.9,
      )
      expect(AskAiLog.last).to have_attributes(
        ask_scope: "topic:#{topic.id}",
        ask_scope_model: "site",
        ask_scope_probability: 0.9,
        ask_intent_model: "answer",
      )
    end

    it "keeps the scope for a search about the place it was made in" do
      topic = Fabricate(:topic, title: "Upgrading to PostgreSQL 18")

      DiscourseAi::Decisions.with_canned_answers(intent: "lookup", scope: "here") do
        expect_enqueued_with(job: :stream_discover_reply, args: { scope: "topic:#{topic.id}" }) do
          post "/discourse-ai/discoveries/reply",
               params: {
                 query: "disk space",
                 request_id:,
                 scope: "topic:#{topic.id}",
                 classify_intent: true,
               }
        end
      end
    end

    it "does not judge for readers without the combined search" do
      SiteSetting.enable_ai_combined_search = false

      DiscourseAi::Decisions.with_canned_answers(intent: "answer") do
        post "/discourse-ai/discoveries/reply",
             params: {
               query: "password reset",
               request_id:,
               classify_intent: true,
             }
      end

      expect(response.status).to eq(200)
      expect(response.parsed_body).not_to have_key("intent")
      expect(AskAiLog.last).to have_attributes(ask_intent_model: "")
    end

    it "does not judge a scoped search again when its request is repeated" do
      topic = Fabricate(:topic)
      params = {
        query: "disk space",
        request_id:,
        scope: "topic:#{topic.id}",
        classify_intent: true,
      }
      DiscourseAi::Decisions.with_canned_answers(intent: "lookup", scope: "here") do
        post("/discourse-ai/discoveries/reply", params:)
        post("/discourse-ai/discoveries/reply", params:)
      end

      expect(response.status).to eq(200)
      expect(AskAiLog.where(user:).count).to eq(1)
      expect(response.parsed_body).not_to have_key("intent")
    end

    it "says the ask failed, rather than answering nothing, when its answer cannot be queued" do
      allow(Jobs).to receive(:enqueue).and_raise(StandardError, "queue unavailable")

      post "/discourse-ai/discoveries/reply", params: { query: "password reset", request_id: }

      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to contain_exactly(
        I18n.t("discourse_ai.ai_bot.discoveries.errors.processing_failed"),
      )
      expect(AskAiLog.last).to be_ask_outcome_failed
    end

    it "says when the reader prefers results in the combined search" do
      4.times do
        AskAiLog.create!(
          user:,
          query: "q",
          asked_at: 1.hour.ago,
          ask_tab_opened: "ask",
          ask_tab_switched_to: "topics",
          ask_tab_switched_after_ms: 1000,
        )
      end

      post "/discourse-ai/discoveries/reply", params: { query: "password reset", request_id: }

      expect(response.parsed_body["prefers_results"]).to eq(true)
    end

    it "logs only the heuristic when no judgement is asked for" do
      post "/discourse-ai/discoveries/reply",
           params: {
             query: "password reset",
             request_id:,
             intent_heuristic: "lookup",
           }

      expect(response.status).to eq(200)
      expect(response.parsed_body).not_to have_key("intent")
      expect(AskAiLog.last).to have_attributes(ask_intent_heuristic: "lookup", ask_intent_model: "")
    end

    it "ignores an unknown heuristic and a missing decision model" do
      SiteSetting.ai_ask_ai_search_intent_decision_model = ""

      post "/discourse-ai/discoveries/reply",
           params: {
             query: "password reset",
             request_id:,
             intent_heuristic: "whatever",
             classify_intent: true,
           }

      expect(response.status).to eq(200)
      expect(response.parsed_body).not_to have_key("intent")
      expect(AskAiLog.last).to have_attributes(ask_intent_heuristic: "", ask_intent_model: "")
    end
  end

  describe "#record_tabs" do
    fab!(:llm_model)
    fab!(:ai_agent) do
      Fabricate(
        :ai_agent,
        allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
        default_llm_id: llm_model.id,
      )
    end
    fab!(:ask_log) { AskAiLog.create!(user:, query: "password reset", asked_at: Time.current) }

    before do
      Group.refresh_automatic_groups!
      SiteSetting.ai_ask_ai_agent = ai_agent.id
    end

    it "records the opened tab and the first switch, keeping each first report" do
      put "/discourse-ai/discoveries/tabs",
          params: {
            ask_log_id: ask_log.id,
            tab_opened: "topics",
            tab_opened_reason: "topic_results",
          }
      expect(response.status).to eq(204)

      put "/discourse-ai/discoveries/tabs",
          params: {
            ask_log_id: ask_log.id,
            tab_switched_to: "ask",
            tab_switched_after_ms: 1200,
          }
      put "/discourse-ai/discoveries/tabs",
          params: {
            ask_log_id: ask_log.id,
            tab_switched_to: "context",
            tab_switched_after_ms: 5000,
          }

      expect(ask_log.reload).to have_attributes(
        ask_tab_opened: "topics",
        ask_tab_opened_reason: "topic_results",
        ask_tab_switched_to: "ask",
        ask_tab_switched_after_ms: 1200,
      )
    end

    it "rejects an unknown tab" do
      put "/discourse-ai/discoveries/tabs", params: { ask_log_id: ask_log.id, tab_opened: "nope" }

      expect(response.status).to eq(400)
      expect(ask_log.reload.ask_tab_opened).to eq("")
    end

    it "does not touch another user's ask" do
      other_log = AskAiLog.create!(user: Fabricate(:user), query: "x", asked_at: Time.current)

      put "/discourse-ai/discoveries/tabs", params: { ask_log_id: other_log.id, tab_opened: "ask" }

      expect(response.status).to eq(404)
      expect(other_log.reload.ask_tab_opened).to eq("")
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
        SiteSetting.ai_ask_ai_agent = ai_agent.id
        SiteSetting.ai_ask_ai_follow_up_agent = follow_up_agent.id
        SiteSetting.ai_ask_ai_allowed_groups = group.id.to_s
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

      it "marks the conversation as continued from a search for the topic view" do
        post "/discourse-ai/discoveries/continue-convo", params: { request_id: }
        get "/t/#{response.parsed_body["topic_id"]}.json"

        expect(response.parsed_body["ai_search_conversation"]).to eq(true)
      end

      it "leaves the sources to the sidebar for readers of the combined search" do
        SiteSetting.enable_ai_combined_search = true

        post "/discourse-ai/discoveries/continue-convo", params: { request_id: }
        topic = Topic.find(response.parsed_body["topic_id"])

        expect(topic.posts.find_by(post_number: 2).raw).to eq(context)
        get "/t/#{topic.id}.json"
        expect(response.parsed_body.dig("ai_search_cited_topics", "topics")).to contain_exactly(
          include("topic_id" => source_post.topic_id, "title" => source_post.topic.title),
        )
      end

      it "limits the private message title to the configured maximum" do
        long_query = "猫" * 1000
        DiscourseAi::Discoveries.store_result(
          user_id: user.id,
          request_id:,
          query: long_query,
          answer: context,
          sources: [{ "post_id" => source_post.id, "topic_id" => source_post.topic_id }],
          agent_id: ai_agent.id,
        )

        post "/discourse-ai/discoveries/continue-convo", params: { request_id: }

        topic = Topic.find(response.parsed_body["topic_id"])
        expect(topic.title.length).to be <= SiteSetting.max_topic_title_length
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

      it "rejects follow-up when the follow-up agent has no dedicated user" do
        follow_up_agent.update!(user: nil)

        expect {
          post "/discourse-ai/discoveries/continue-convo", params: { request_id: }
        }.not_to change(Topic, :count)

        expect(response).to have_http_status(:unprocessable_entity)
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
        SiteSetting.ai_ask_ai_agent = ai_agent.id
        SiteSetting.ai_ask_ai_enabled = false
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
