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
    SiteSetting.ai_hugging_face_tei_reranker_endpoint = "https://reranker.example.com"
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
      SiteSetting.ai_hugging_face_tei_reranker_endpoint = "https://reranker.example.com"
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
        expect {
          post "/discourse-ai/discoveries/reply",
               params: {
                 query: "What is Discourse?",
                 request_id:,
               }
        }.to change(Jobs::StreamDiscoverReply.jobs, :size).by(1)

        expect(response.status).to eq(200)
        expect(response.parsed_body["request_id"]).to eq(request_id)
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
    let(:query) { "What is Discourse?" }
    let(:context) { "Discourse is an open-source discussion platform." }
    let(:request_id) { SecureRandom.uuid }
    fab!(:source_post, :post)

    context "when the user is allowed to discover" do
      before do
        SiteSetting.ai_discover_agent = ai_agent.id
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

      it "does not expose unexpected follow-up errors" do
        allow(PostCreator).to receive(:create!).and_raise("sensitive internal detail")

        post "/discourse-ai/discoveries/continue-convo", params: { request_id: }

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"].join).to include(
          I18n.t("discourse_ai.ai_bot.discoveries.errors.follow_up_failed"),
        )
        expect(response.parsed_body["errors"].join).not_to include("sensitive internal detail")
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
