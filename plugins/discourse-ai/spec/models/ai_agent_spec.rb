# frozen_string_literal: true

RSpec.describe AiAgent do
  subject(:basic_agent) do
    AiAgent.new(
      name: "test",
      description: "test",
      system_prompt: "test",
      tools: [],
      allowed_group_ids: [],
    )
  end

  fab!(:llm_model)
  fab!(:seeded_llm_model) { Fabricate(:llm_model, id: -1) }

  before { enable_current_plugin }

  it "validates context settings" do
    expect(basic_agent.valid?).to eq(true)

    basic_agent.max_context_posts = 0
    expect(basic_agent.valid?).to eq(false)
    expect(basic_agent.errors[:max_context_posts]).to eq(["must be greater than 0"])

    basic_agent.max_context_posts = 1
    expect(basic_agent.valid?).to eq(true)

    basic_agent.max_context_posts = nil
    expect(basic_agent.valid?).to eq(true)
  end

  it "validates tools" do
    Fabricate(:ai_tool, id: 1)
    Fabricate(:ai_tool, id: 2, name: "Archie search", tool_name: "search")

    expect(basic_agent.valid?).to eq(true)

    basic_agent.tools = %w[search image_generation]
    expect(basic_agent.valid?).to eq(true)

    basic_agent.tools = %w[search image_generation search]
    expect(basic_agent.valid?).to eq(false)
    expect(basic_agent.errors[:tools]).to eq(["Can not have duplicate tools"])

    basic_agent.tools = [
      ["custom-1", { test: "test" }, false],
      ["custom-2", { test: "test" }, false],
    ]
    expect(basic_agent.valid?).to eq(true)
    expect(basic_agent.errors[:tools]).to eq([])

    basic_agent.tools = [
      ["custom-1", { test: "test" }, false],
      ["custom-1", { test: "test" }, false],
    ]
    expect(basic_agent.valid?).to eq(false)
    expect(basic_agent.errors[:tools]).to eq(["Can not have duplicate tools"])

    basic_agent.tools = [
      ["custom-1", { test: "test" }, false],
      ["custom-2", { test: "test" }, false],
      "image_generation",
    ]
    expect(basic_agent.valid?).to eq(true)
    expect(basic_agent.errors[:tools]).to eq([])

    basic_agent.tools = [
      ["custom-1", { test: "test" }, false],
      ["custom-2", { test: "test" }, false],
      "Search",
    ]
    expect(basic_agent.valid?).to eq(false)
    expect(basic_agent.errors[:tools]).to eq(["Can not have duplicate tools"])
  end

  it "allows creation of user" do
    user = basic_agent.create_user!
    expect(user.username).to eq("test_bot")
    expect(user.name).to eq("Test")
    expect(user.bot?).to be(true)
    expect(user.id).to be <= AiAgent::FIRST_AGENT_USER_ID
  end

  it "removes all rag embeddings when rag params change" do
    agent =
      AiAgent.create!(
        name: "test",
        description: "test",
        system_prompt: "test",
        tools: [],
        allowed_group_ids: [],
        rag_chunk_tokens: 10,
        rag_chunk_overlap_tokens: 5,
      )

    id =
      RagDocumentFragment.create!(
        target: agent,
        fragment: "test",
        fragment_number: 1,
        upload: Fabricate(:upload),
      ).id

    agent.rag_chunk_tokens = 20
    agent.save!

    expect(RagDocumentFragment.exists?(id)).to eq(false)
  end

  it "defines singleton methods on system agent classes" do
    forum_helper = AiAgent.find_by(name: "Forum Helper")
    forum_helper.update!(
      user_id: 1,
      default_llm_id: llm_model.id,
      max_context_posts: 3,
      allow_topic_mentions: true,
      allow_personal_messages: true,
      allow_chat_channel_mentions: true,
      allow_chat_direct_messages: true,
    )

    klass = forum_helper.class_instance

    expect(klass.id).to eq(forum_helper.id)
    expect(klass.system).to eq(true)
    # tl 0 by default
    expect(klass.allowed_group_ids).to eq([10])
    expect(klass.user_id).to eq(1)
    expect(klass.default_llm_id).to eq(llm_model.id)
    expect(klass.max_context_posts).to eq(3)
    expect(klass.allow_topic_mentions).to eq(true)
    expect(klass.allow_personal_messages).to eq(true)
    expect(klass.allow_chat_channel_mentions).to eq(true)
    expect(klass.allow_chat_direct_messages).to eq(true)
  end

  it "defines singleton methods non agent classes" do
    agent =
      AiAgent.create!(
        name: "test",
        description: "test",
        system_prompt: "test",
        tools: [],
        allowed_group_ids: [],
        default_llm_id: llm_model.id,
        max_context_posts: 3,
        allow_topic_mentions: true,
        allow_personal_messages: true,
        allow_chat_channel_mentions: true,
        allow_chat_direct_messages: true,
        user_id: 1,
      )

    klass = agent.class_instance

    expect(klass.id).to eq(agent.id)
    expect(klass.system).to eq(false)
    expect(klass.allowed_group_ids).to eq([])
    expect(klass.user_id).to eq(1)
    expect(klass.default_llm_id).to eq(llm_model.id)
    expect(klass.max_context_posts).to eq(3)
    expect(klass.allow_topic_mentions).to eq(true)
    expect(klass.allow_personal_messages).to eq(true)
    expect(klass.allow_chat_channel_mentions).to eq(true)
    expect(klass.allow_chat_direct_messages).to eq(true)
  end

  it "does not allow setting allowing chat without a default_llm" do
    agent =
      AiAgent.create(
        name: "test",
        description: "test",
        system_prompt: "test",
        allowed_group_ids: [],
        default_llm: nil,
        allow_chat_channel_mentions: true,
      )

    expect(agent.valid?).to eq(false)
    expect(agent.errors[:default_llm].first).to eq(
      I18n.t("discourse_ai.ai_bot.agents.default_llm_required"),
    )

    agent =
      AiAgent.create(
        name: "test",
        description: "test",
        system_prompt: "test",
        allowed_group_ids: [],
        default_llm: nil,
        allow_chat_direct_messages: true,
      )

    expect(agent.valid?).to eq(false)
    expect(agent.errors[:default_llm].first).to eq(
      I18n.t("discourse_ai.ai_bot.agents.default_llm_required"),
    )

    agent =
      AiAgent.create(
        name: "test",
        description: "test",
        system_prompt: "test",
        allowed_group_ids: [],
        default_llm: nil,
        allow_topic_mentions: true,
      )

    expect(agent.valid?).to eq(false)
    expect(agent.errors[:default_llm].first).to eq(
      I18n.t("discourse_ai.ai_bot.agents.default_llm_required"),
    )
  end

  it "does not leak caches between sites" do
    AiAgent.create!(
      name: "pun_bot",
      description: "you write puns",
      system_prompt: "you are pun bot",
      tools: ["ImageCommand"],
      allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
    )

    AiAgent.all_agents

    expect(AiAgent.agent_cache[:value].length).to be > (0)
    RailsMultisite::ConnectionManagement.stubs(:current_db) { "abc" }
    expect(AiAgent.agent_cache[:value]).to eq(nil)
  end

  describe ".find_by_id_from_cache" do
    fab!(:agent) do
      AiAgent.create!(
        name: "cached_agent",
        description: "test agent for cache",
        system_prompt: "you are a test",
        tools: [],
        allowed_group_ids: [],
      )
    end

    it "returns nil for blank agent_id" do
      expect(AiAgent.find_by_id_from_cache(nil)).to eq(nil)
      expect(AiAgent.find_by_id_from_cache("")).to eq(nil)
    end

    it "finds agent by id from cache" do
      result = AiAgent.find_by_id_from_cache(agent.id)
      expect(result).to be_present
      expect(result.id).to eq(agent.id)
      expect(result.name).to eq("cached_agent")
    end

    it "finds agent when id is provided as a string" do
      result = AiAgent.find_by_id_from_cache(agent.id.to_s)
      expect(result).to be_present
      expect(result.id).to eq(agent.id)
    end

    it "returns nil for non-existent agent id" do
      result = AiAgent.find_by_id_from_cache(999_999)
      expect(result).to eq(nil)
    end

    it "finds disabled agents" do
      agent.update!(enabled: false)
      result = AiAgent.find_by_id_from_cache(agent.id)
      expect(result).to be_present
      expect(result.id).to eq(agent.id)
    end

    it "uses cache and avoids database queries after initial load" do
      AiAgent.find_by_id_from_cache(agent.id)

      query_count = track_sql_queries { AiAgent.find_by_id_from_cache(agent.id) }.count

      expect(query_count).to eq(0)
    end

    it "falls back to database when cache is cleared after initial load" do
      result_before = AiAgent.find_by_id_from_cache(agent.id)
      expect(result_before).to be_present

      AiAgent.agent_cache.flush!

      query_count =
        track_sql_queries do
          result_after = AiAgent.find_by_id_from_cache(agent.id)
          expect(result_after).to be_present
          expect(result_after.id).to eq(agent.id)
          expect(result_after.name).to eq("cached_agent")
        end.count

      expect(query_count).to be > 0
    end
  end

  describe "system agent validations" do
    let(:system_agent) do
      AiAgent.create!(
        name: "system_agent",
        description: "system agent",
        system_prompt: "system agent",
        tools: %w[Search Time],
        response_format: [{ key: "summary", type: "string" }],
        examples: [%w[user_msg1 assistant_msg1], %w[user_msg2 assistant_msg2]],
        system: true,
      )
    end

    context "when modifying a system agent" do
      it "allows changing tool options without allowing tool additions/removals" do
        tools = [["Search", { "base_query" => "abc" }], ["Time"]]
        system_agent.update!(tools: tools)

        system_agent.reload
        expect(system_agent.tools).to eq(tools)

        invalid_tools = ["Time"]
        system_agent.update(tools: invalid_tools)
        expect(system_agent.errors[:base]).to include(
          I18n.t("discourse_ai.ai_bot.agents.cannot_edit_system_agent"),
        )
      end

      it "doesn't accept response format changes" do
        new_format = [{ key: "summary2", type: "string" }]

        expect { system_agent.update!(response_format: new_format) }.to raise_error(
          ActiveRecord::RecordInvalid,
        )
      end

      it "doesn't accept additional format changes" do
        new_format = [{ key: "summary", type: "string" }, { key: "summary2", type: "string" }]

        expect { system_agent.update!(response_format: new_format) }.to raise_error(
          ActiveRecord::RecordInvalid,
        )
      end

      it "doesn't accept changes to examples" do
        other_examples = [%w[user_msg1 assistant_msg1]]

        expect { system_agent.update!(examples: other_examples) }.to raise_error(
          ActiveRecord::RecordInvalid,
        )
      end
    end
  end

  describe "agentic execution mode defaults and propagation" do
    it "assigns safe defaults to a agent created without agentic fields" do
      agent =
        AiAgent.create!(
          name: "legacy_agent",
          description: "no agentic fields set",
          system_prompt: "test",
          tools: [],
          allowed_group_ids: [],
        )

      expect(agent.execution_mode).to eq("default")
      expect(agent.max_turn_tokens).to be_nil
      expect(agent.compression_threshold).to be_nil

      klass = agent.class_instance

      expect(klass.execution_mode).to eq("default")
      expect(klass.max_turn_tokens).to be_nil
      expect(klass.compression_threshold).to be_nil
    end

    it "requires compression_threshold for agentic mode but not for default mode" do
      agent =
        AiAgent.new(
          name: "agentic_agent",
          description: "test",
          system_prompt: "test",
          tools: [],
          allowed_group_ids: [],
          execution_mode: "agentic",
        )

      expect(agent.valid?).to eq(false)
      expect(agent.errors[:compression_threshold]).to be_present

      agent.compression_threshold = 75
      expect(agent.valid?).to eq(true)

      agent.execution_mode = "default"
      agent.compression_threshold = nil
      expect(agent.valid?).to eq(true)
    end
  end

  describe "validates examples format" do
    it "doesn't accept examples that are not arrays" do
      basic_agent.examples = [1]

      expect(basic_agent.valid?).to eq(false)
      expect(basic_agent.errors[:examples].first).to eq(
        I18n.t("discourse_ai.agents.malformed_examples"),
      )
    end

    it "doesn't accept examples that don't come in pairs" do
      basic_agent.examples = [%w[user_msg1]]

      expect(basic_agent.valid?).to eq(false)
      expect(basic_agent.errors[:examples].first).to eq(
        I18n.t("discourse_ai.agents.malformed_examples"),
      )
    end

    it "works when example is well formatted" do
      basic_agent.examples = [%w[user_msg1 assistant1]]

      expect(basic_agent.valid?).to eq(true)
    end
  end
end
