# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseAi::Agents::Tools::SearchUploadedDocuments do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:vector_def, :embedding_definition)

  fab!(:ai_agent) do
    Group.refresh_automatic_groups!
    Fabricate(
      :ai_agent,
      name: "upload helper",
      rag_conversation_chunks: 3,
      allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
    )
  end

  let(:upload) { Fabricate(:upload, original_filename: "guide.md") }
  let(:other_upload) { Fabricate(:upload, original_filename: "faq.md") }

  before do
    enable_current_plugin
    SiteSetting.authorized_extensions = "md|txt"
    SiteSetting.ai_embeddings_selected_model = vector_def.id
    SiteSetting.ai_embeddings_enabled = true

    UploadReference.ensure_exist!(target: ai_agent, upload_ids: [upload.id, other_upload.id])
  end

  let(:agent) { DiscourseAi::Agents::Agent.find_by(id: ai_agent.id, user: user).new }
  let(:embedding_value) { 0.04381 }
  let(:query_embeddings) { [embedding_value] * vector_def.dimensions }

  def store_fragment(text:, upload:, index:, embeddings: nil)
    fragment =
      Fabricate(
        :rag_document_fragment,
        fragment: text,
        target: ai_agent,
        upload: upload,
        fragment_number: index + 1,
      )

    embeddings ||= [embedding_value + "0.000#{index}".to_f] * vector_def.dimensions
    DiscourseAi::Embeddings::Schema.for(RagDocumentFragment).store(fragment, embeddings, "test")
  end

  it "returns no more excerpts than the agent rag setting allows" do
    store_fragment(text: "fragment-n0", upload: upload, index: 0)
    store_fragment(text: "fragment-n1", upload: upload, index: 1)
    store_fragment(text: "fragment-n2", upload: upload, index: 2)
    store_fragment(text: "fragment-n3", upload: upload, index: 3)

    EmbeddingsGenerationStubs.hugging_face_service("tell me the time", query_embeddings)

    tool =
      described_class.new(
        { query: "tell me the time", limit: 10 },
        bot_user: nil,
        llm: nil,
        agent: agent,
      )

    result = tool.invoke

    excerpt_contents = result[:excerpts].map { |excerpt| excerpt[:content] }

    expect(excerpt_contents.length).to eq(ai_agent.rag_conversation_chunks)
    expect(excerpt_contents).to all(be_in(%w[fragment-n0 fragment-n1 fragment-n2 fragment-n3]))
    expect(excerpt_contents.uniq.length).to eq(ai_agent.rag_conversation_chunks)
  end

  it "can restrict search to specific filenames" do
    store_fragment(text: "guide fragment", upload: upload, index: 0)
    store_fragment(text: "faq fragment", upload: other_upload, index: 1)

    EmbeddingsGenerationStubs.hugging_face_service("uploaded docs", query_embeddings)

    tool =
      described_class.new(
        { query: "uploaded docs", filenames: ["faq.md"] },
        bot_user: nil,
        llm: nil,
        agent: agent,
      )

    result = tool.invoke

    expect(result[:excerpts]).to contain_exactly(
      { filename: "faq.md", metadata: nil, fragment_number: 2, content: "faq fragment" },
    )
    expect(result[:filenames]).to eq(["faq.md"])
  end

  it "prioritizes a lowercase glossary query over semantically similar excerpts" do
    glossary = "| Apothecary Skill | Arzneikunde-Fähigkeit |"
    store_fragment(text: glossary, upload: upload, index: 0)
    store_fragment(text: "Making potions", upload: upload, index: 1)
    store_fragment(text: "Collecting herbs", upload: upload, index: 2)
    exact_fragment = RagDocumentFragment.find_by!(fragment: glossary, target: ai_agent)
    DiscourseAi::Embeddings::Schema.for(RagDocumentFragment).store(
      exact_fragment,
      query_embeddings.map { |value| -value },
      "test",
    )
    EmbeddingsGenerationStubs.hugging_face_service("apothecary skill", query_embeddings)

    result =
      described_class.new(
        { query: "apothecary skill", limit: 1 },
        bot_user: nil,
        llm: nil,
        agent: agent,
      ).invoke

    expect(result[:excerpts].map { |excerpt| excerpt[:content] }).to eq([glossary])
  end

  it "keeps exact matches within the agent and requested file" do
    other_agent = Fabricate(:ai_agent)
    Fabricate(:rag_document_fragment, target: other_agent, upload: upload, fragment: "猫_100%")
    store_fragment(text: "猫_100% in another file", upload: other_upload, index: 0)
    store_fragment(text: "猫X1000", upload: upload, index: 1)
    store_fragment(text: "猫_100%", upload: upload, index: 2)
    EmbeddingsGenerationStubs.hugging_face_service("猫_100%", query_embeddings)

    result =
      described_class.new(
        { query: "猫_100%", filenames: ["guide.md"], limit: 1 },
        bot_user: nil,
        llm: nil,
        agent: agent,
      ).invoke

    expect(result[:excerpts]).to eq(
      [{ filename: "guide.md", metadata: nil, fragment_number: 3, content: "猫_100%" }],
    )
  end

  it "fills remaining results with semantic matches without repeating exact matches" do
    store_fragment(text: "Apothecary Skill", upload: upload, index: 0)
    store_fragment(text: "Making potions", upload: upload, index: 1)
    EmbeddingsGenerationStubs.hugging_face_service("apothecary skill", query_embeddings)

    result =
      described_class.new(
        { query: "apothecary skill", limit: 3 },
        bot_user: nil,
        llm: nil,
        agent: agent,
      ).invoke

    expect(result[:excerpts].map { |excerpt| excerpt[:content] }).to eq(
      ["Apothecary Skill", "Making potions"],
    )
  end

  it "does not prioritize a query found inside another word" do
    store_fragment(
      text: "Party planning",
      upload: upload,
      index: 0,
      embeddings: query_embeddings.map { |value| -value },
    )
    store_fragment(text: "Painting and sculpture", upload: upload, index: 1)
    EmbeddingsGenerationStubs.hugging_face_service("art", query_embeddings)

    result =
      described_class.new({ query: "art", limit: 1 }, bot_user: nil, llm: nil, agent: agent).invoke

    expect(result[:excerpts].map { |excerpt| excerpt[:content] }).to eq(["Painting and sculpture"])
  end

  it "ranks whole phrase matches by relevance when they exceed the result limit" do
    store_fragment(
      text: "Art history",
      upload: upload,
      index: 0,
      embeddings: query_embeddings.map { |value| -value },
    )
    store_fragment(
      text: "Art supplies",
      upload: upload,
      index: 1,
      embeddings:
        query_embeddings.each_with_index.map { |value, index| index.even? ? value : -value },
    )
    store_fragment(text: "Art classes", upload: upload, index: 2)
    EmbeddingsGenerationStubs.hugging_face_service("art", query_embeddings)

    result =
      described_class.new({ query: "art", limit: 2 }, bot_user: nil, llm: nil, agent: agent).invoke

    expect(result[:excerpts].map { |excerpt| excerpt[:content] }).to eq(
      ["Art classes", "Art supplies"],
    )
  end

  it "matches punctuation in a term literally" do
    store_fragment(text: "C programming", upload: upload, index: 0)
    store_fragment(text: "| C++ | C++ |", upload: upload, index: 1)
    EmbeddingsGenerationStubs.hugging_face_service("C++", query_embeddings)

    result =
      described_class.new({ query: "C++", limit: 1 }, bot_user: nil, llm: nil, agent: agent).invoke

    expect(result[:excerpts].map { |excerpt| excerpt[:content] }).to eq(["| C++ | C++ |"])
  end
end
