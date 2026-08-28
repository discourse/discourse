# frozen_string_literal: true

describe DiscourseAi::Discoveries do
  fab!(:user)
  fab!(:allowed_group, :group)
  fab!(:agent_group, :group)
  fab!(:llm_model)
  fab!(:ai_agent) do
    Fabricate(:ai_agent, allowed_group_ids: [agent_group.id], default_llm_id: llm_model.id)
  end

  before do
    enable_current_plugin
    SiteSetting.ai_ask_ai_enabled = true
    SiteSetting.ai_ask_ai_agent = ai_agent.id
    SiteSetting.ai_ask_ai_allowed_groups = allowed_group.id.to_s
    SiteSetting.ai_embeddings_enabled = true
    SiteSetting.ai_embeddings_semantic_search_enabled = true
    allowed_group.add(user)
    agent_group.add(user)
  end

  describe ".enabled_for_user?" do
    it "allows a user who satisfies the site, agent, model, and retrieval policies" do
      expect(described_class.enabled_for_user?(user)).to eq(true)
    end

    it "checks the site allowed-groups policy" do
      SiteSetting.ai_ask_ai_allowed_groups = Group::AUTO_GROUPS[:admins].to_s

      expect(described_class.enabled_for_user?(user)).to eq(false)
    end

    it "does not use the deprecated Discoveries preference" do
      user.user_option.update!(ai_search_discoveries: false)

      expect(described_class.enabled_for_user?(user)).to eq(true)
    end

    it "requires the configured agent to be enabled" do
      ai_agent.update!(enabled: false)

      expect(described_class.enabled_for_user?(user)).to eq(false)
    end

    it "does not require the optional query rewrite agent" do
      SiteSetting.ai_ask_ai_query_rewriter_agent = 99_999

      expect(described_class.enabled_for_user?(user)).to eq(true)
    end

    it "requires semantic search" do
      SiteSetting.ai_embeddings_semantic_search_enabled = false

      expect(described_class.enabled_for_user?(user)).to eq(false)
    end
  end

  describe ".result_settings" do
    it "returns the configured Ask AI presentation settings" do
      SiteSetting.ai_ask_ai_summary_detail = "detailed"
      SiteSetting.ai_ask_ai_related_count = 5

      expect(described_class.result_settings).to eq(summary_detail: :detailed, related_count: 5)
    end
  end

  describe ".record_recent_ask" do
    it "does not store queries when search logging is disabled" do
      SiteSetting.log_search_queries = false

      described_class.record_recent_ask(user_id: user.id, query: "private question")

      expect(described_class.recent_asks(user_id: user.id)).to be_empty
    end

    it "removes stored queries when the user is destroyed" do
      target_user = Fabricate(:user)
      described_class.record_recent_ask(user_id: target_user.id, query: "private question")

      UserDestroyer.new(Fabricate(:admin)).destroy(target_user)

      expect(described_class.recent_asks(user_id: target_user.id)).to be_empty
    end
  end

  describe ".bind_request" do
    it "atomically binds a request ID to one normalized query" do
      request_id = SecureRandom.uuid

      expect(
        described_class.bind_request(user_id: user.id, request_id:, query: "  猫 search  "),
      ).to eq(:created)
      expect(
        described_class.bind_request(user_id: user.id, request_id:, query: "猫   search"),
      ).to eq(:existing)
      expect {
        described_class.bind_request(user_id: user.id, request_id:, query: "dogs")
      }.to raise_error(DiscourseAi::Discoveries::RequestConflict)
    end

    it "makes the newest request active without allowing an old retry to reclaim ownership" do
      old_request_id = SecureRandom.uuid
      new_request_id = SecureRandom.uuid

      described_class.bind_request(user_id: user.id, request_id: old_request_id, query: "cats")
      described_class.bind_request(user_id: user.id, request_id: new_request_id, query: "dogs")

      expect(described_class.active_request?(user.id, old_request_id)).to eq(false)
      expect(described_class.active_request?(user.id, new_request_id)).to eq(true)

      expect(
        described_class.bind_request(user_id: user.id, request_id: old_request_id, query: "cats"),
      ).to eq(:existing)
      expect(described_class.active_request?(user.id, new_request_id)).to eq(true)
    end
  end

  describe ".admit_request" do
    it "limits concurrent site work and releases capacity" do
      request_ids = Array.new(5) { SecureRandom.uuid }

      begin
        request_ids
          .first(4)
          .each_with_index do |request_id, index|
            expect(described_class.admit_request(user_id: index + 1, request_id:)).to eq(true)
          end
        expect(described_class.admit_request(user_id: 5, request_id: request_ids.last)).to eq(false)

        described_class.release_request(user_id: 1, request_id: request_ids.first)

        expect(described_class.admit_request(user_id: 5, request_id: request_ids.last)).to eq(true)
      ensure
        request_ids.each_with_index do |request_id, index|
          described_class.release_request(user_id: index + 1, request_id:)
        end
      end
    end
  end

  describe ".cached_result_for" do
    fab!(:post)

    it "returns only a user-owned result whose sources are still visible" do
      request_id = SecureRandom.uuid
      described_class.store_result(
        user_id: user.id,
        request_id:,
        query: "猫 search",
        answer: "A useful answer.",
        sources: [{ "post_id" => post.id, "topic_id" => post.topic_id }],
        agent_id: ai_agent.id,
      )

      result = described_class.cached_result_for(user:, request_id:)
      expect(result).to include(
        "query" => "猫 search",
        "answer" => "A useful answer.",
        "agent_id" => ai_agent.id,
      )
      expect(described_class.cached_result_for(user: Fabricate(:user), request_id:)).to be_nil

      private_category = Fabricate(:private_category, group: Fabricate(:group))
      post.topic.update!(category: private_category)
      expect(described_class.cached_result_for(user:, request_id:)).to be_nil
    end

    it "invalidates follow-up context when a supporting post changes" do
      request_id = SecureRandom.uuid
      described_class.store_result(
        user_id: user.id,
        request_id:,
        query: "plugin setup",
        answer: "A useful answer.",
        sources: [{ "post_id" => post.id, "topic_id" => post.topic_id }],
        agent_id: ai_agent.id,
      )

      post.update!(raw: "Updated supporting content")

      expect(described_class.cached_result_for(user:, request_id:)).to be_nil
    end

    it "keeps source-only context for follow-up without generated prose" do
      request_id = SecureRandom.uuid
      described_class.store_result(
        user_id: user.id,
        request_id:,
        query: "猫 search",
        answer: "",
        sources: [{ "post_id" => post.id, "topic_id" => post.topic_id }],
        agent_id: ai_agent.id,
      )

      result = described_class.cached_result_for(user:, request_id:)
      expect(result).to include("query" => "猫 search", "answer" => "")
      expect(result.fetch("sources").first).to include(
        "title" => post.topic.title,
        "url" => post.full_url,
      )
    end
  end
end
