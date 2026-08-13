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
    SiteSetting.ai_discover_enabled = true
    SiteSetting.ai_discover_agent = ai_agent.id
    SiteSetting.ai_discover_allowed_groups = allowed_group.id.to_s
    SiteSetting.ai_embeddings_enabled = true
    SiteSetting.ai_embeddings_semantic_search_enabled = true
    SiteSetting.ai_hugging_face_tei_reranker_endpoint = "https://reranker.example.com"
    allowed_group.add(user)
    agent_group.add(user)
  end

  describe ".enabled_for_user?" do
    it "allows a user who satisfies the site, agent, model, retrieval, and user-option policies" do
      expect(described_class.enabled_for_user?(user)).to eq(true)
    end

    it "checks the site allowed-groups policy independently of the user option" do
      SiteSetting.ai_discover_allowed_groups = Group::AUTO_GROUPS[:admins].to_s
      user.user_option.update!(ai_search_discoveries: true)

      expect(described_class.enabled_for_user?(user)).to eq(false)
    end

    it "rejects a user who disabled Discoveries" do
      user.user_option.update!(ai_search_discoveries: false)

      expect(described_class.enabled_for_user?(user)).to eq(false)
    end

    it "requires the configured agent to be enabled" do
      ai_agent.update!(enabled: false)

      expect(described_class.enabled_for_user?(user)).to eq(false)
    end

    it "requires semantic search and the reranker used by the bounded pipeline" do
      SiteSetting.ai_embeddings_semantic_search_enabled = false
      expect(described_class.enabled_for_user?(user)).to eq(false)

      SiteSetting.ai_embeddings_semantic_search_enabled = true
      SiteSetting.ai_hugging_face_tei_reranker_endpoint = ""
      expect(described_class.enabled_for_user?(user)).to eq(false)
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
  end
end
