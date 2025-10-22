# frozen_string_literal: true

RSpec.describe AiPersona do
  subject(:basic_persona) do
    AiPersona.new(
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
    expect(basic_persona.valid?).to eq(true)

    basic_persona.max_context_posts = 0
    expect(basic_persona.valid?).to eq(false)
    expect(basic_persona.errors[:max_context_posts]).to eq(["must be greater than 0"])

    basic_persona.max_context_posts = 1
    expect(basic_persona.valid?).to eq(true)

    basic_persona.max_context_posts = nil
    expect(basic_persona.valid?).to eq(true)
  end

  it "validates tools" do
    Fabricate(:ai_tool, id: 1)
    Fabricate(:ai_tool, id: 2, name: "Archie search", tool_name: "search")

    expect(basic_persona.valid?).to eq(true)

    basic_persona.tools = %w[search image_generation]
    expect(basic_persona.valid?).to eq(true)

    basic_persona.tools = %w[search image_generation search]
    expect(basic_persona.valid?).to eq(false)
    expect(basic_persona.errors[:tools]).to eq(["Can not have duplicate tools"])

    basic_persona.tools = [
      ["custom-1", { test: "test" }, false],
      ["custom-2", { test: "test" }, false],
    ]
    expect(basic_persona.valid?).to eq(true)
    expect(basic_persona.errors[:tools]).to eq([])

    basic_persona.tools = [
      ["custom-1", { test: "test" }, false],
      ["custom-1", { test: "test" }, false],
    ]
    expect(basic_persona.valid?).to eq(false)
    expect(basic_persona.errors[:tools]).to eq(["Can not have duplicate tools"])

    basic_persona.tools = [
      ["custom-1", { test: "test" }, false],
      ["custom-2", { test: "test" }, false],
      "image_generation",
    ]
    expect(basic_persona.valid?).to eq(true)
    expect(basic_persona.errors[:tools]).to eq([])

    basic_persona.tools = [
      ["custom-1", { test: "test" }, false],
      ["custom-2", { test: "test" }, false],
      "Search",
    ]
    expect(basic_persona.valid?).to eq(false)
    expect(basic_persona.errors[:tools]).to eq(["Can not have duplicate tools"])
  end

  it "allows creation of user" do
    user = basic_persona.create_user!
    expect(user.username).to eq("test_bot")
    expect(user.name).to eq("Test")
    expect(user.bot?).to be(true)
    expect(user.id).to be <= AiPersona::FIRST_PERSONA_USER_ID
  end

  it "removes all rag embeddings when rag params change" do
    persona =
      AiPersona.create!(
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
        target: persona,
        fragment: "test",
        fragment_number: 1,
        upload: Fabricate(:upload),
      ).id

    persona.rag_chunk_tokens = 20
    persona.save!

    expect(RagDocumentFragment.exists?(id)).to eq(false)
  end

  it "defines singleton methods on system persona classes" do
    forum_helper = AiPersona.find_by(name: "Forum Helper")
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

  it "defines singleton methods non persona classes" do
    persona =
      AiPersona.create!(
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

    klass = persona.class_instance

    expect(klass.id).to eq(persona.id)
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
    persona =
      AiPersona.create(
        name: "test",
        description: "test",
        system_prompt: "test",
        allowed_group_ids: [],
        default_llm: nil,
        allow_chat_channel_mentions: true,
      )

    expect(persona.valid?).to eq(false)
    expect(persona.errors[:default_llm].first).to eq(
      I18n.t("discourse_ai.ai_bot.personas.default_llm_required"),
    )

    persona =
      AiPersona.create(
        name: "test",
        description: "test",
        system_prompt: "test",
        allowed_group_ids: [],
        default_llm: nil,
        allow_chat_direct_messages: true,
      )

    expect(persona.valid?).to eq(false)
    expect(persona.errors[:default_llm].first).to eq(
      I18n.t("discourse_ai.ai_bot.personas.default_llm_required"),
    )

    persona =
      AiPersona.create(
        name: "test",
        description: "test",
        system_prompt: "test",
        allowed_group_ids: [],
        default_llm: nil,
        allow_topic_mentions: true,
      )

    expect(persona.valid?).to eq(false)
    expect(persona.errors[:default_llm].first).to eq(
      I18n.t("discourse_ai.ai_bot.personas.default_llm_required"),
    )
  end

  it "does not leak caches between sites" do
    AiPersona.create!(
      name: "pun_bot",
      description: "you write puns",
      system_prompt: "you are pun bot",
      tools: ["ImageCommand"],
      allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
    )

    AiPersona.all_personas

    expect(AiPersona.persona_cache[:value].length).to be > (0)
    RailsMultisite::ConnectionManagement.stubs(:current_db) { "abc" }
    expect(AiPersona.persona_cache[:value]).to eq(nil)
  end

  describe ".find_by_id_from_cache" do
    fab!(:persona) do
      AiPersona.create!(
        name: "cached_persona",
        description: "test persona for cache",
        system_prompt: "you are a test",
        tools: [],
        allowed_group_ids: [],
      )
    end

    it "returns nil for blank persona_id" do
      expect(AiPersona.find_by_id_from_cache(nil)).to eq(nil)
      expect(AiPersona.find_by_id_from_cache("")).to eq(nil)
    end

    it "finds persona by id from cache" do
      result = AiPersona.find_by_id_from_cache(persona.id)
      expect(result).to be_present
      expect(result.id).to eq(persona.id)
      expect(result.name).to eq("cached_persona")
    end

    it "returns nil for non-existent persona id" do
      result = AiPersona.find_by_id_from_cache(999_999)
      expect(result).to eq(nil)
    end

    it "finds disabled personas" do
      persona.update!(enabled: false)
      result = AiPersona.find_by_id_from_cache(persona.id)
      expect(result).to be_present
      expect(result.id).to eq(persona.id)
    end

    it "uses cache and avoids database queries after initial load" do
      AiPersona.find_by_id_from_cache(persona.id)

      query_count = track_sql_queries { AiPersona.find_by_id_from_cache(persona.id) }.count

      expect(query_count).to eq(0)
    end
  end

  describe "system persona validations" do
    let(:system_persona) do
      AiPersona.create!(
        name: "system_persona",
        description: "system persona",
        system_prompt: "system persona",
        tools: %w[Search Time],
        response_format: [{ key: "summary", type: "string" }],
        examples: [%w[user_msg1 assistant_msg1], %w[user_msg2 assistant_msg2]],
        system: true,
      )
    end

    context "when modifying a system persona" do
      it "allows changing tool options without allowing tool additions/removals" do
        tools = [["Search", { "base_query" => "abc" }], ["Time"]]
        system_persona.update!(tools: tools)

        system_persona.reload
        expect(system_persona.tools).to eq(tools)

        invalid_tools = ["Time"]
        system_persona.update(tools: invalid_tools)
        expect(system_persona.errors[:base]).to include(
          I18n.t("discourse_ai.ai_bot.personas.cannot_edit_system_persona"),
        )
      end

      it "doesn't accept response format changes" do
        new_format = [{ key: "summary2", type: "string" }]

        expect { system_persona.update!(response_format: new_format) }.to raise_error(
          ActiveRecord::RecordInvalid,
        )
      end

      it "doesn't accept additional format changes" do
        new_format = [{ key: "summary", type: "string" }, { key: "summary2", type: "string" }]

        expect { system_persona.update!(response_format: new_format) }.to raise_error(
          ActiveRecord::RecordInvalid,
        )
      end

      it "doesn't accept changes to examples" do
        other_examples = [%w[user_msg1 assistant_msg1]]

        expect { system_persona.update!(examples: other_examples) }.to raise_error(
          ActiveRecord::RecordInvalid,
        )
      end
    end
  end

  describe "validates examples format" do
    it "doesn't accept examples that are not arrays" do
      basic_persona.examples = [1]

      expect(basic_persona.valid?).to eq(false)
      expect(basic_persona.errors[:examples].first).to eq(
        I18n.t("discourse_ai.personas.malformed_examples"),
      )
    end

    it "doesn't accept examples that don't come in pairs" do
      basic_persona.examples = [%w[user_msg1]]

      expect(basic_persona.valid?).to eq(false)
      expect(basic_persona.errors[:examples].first).to eq(
        I18n.t("discourse_ai.personas.malformed_examples"),
      )
    end

    it "works when example is well formatted" do
      basic_persona.examples = [%w[user_msg1 assistant1]]

      expect(basic_persona.valid?).to eq(true)
    end
  end
end
