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

  def store_fragment(text:, upload:, index:)
    fragment =
      Fabricate(
        :rag_document_fragment,
        fragment: text,
        target: ai_agent,
        upload: upload,
        fragment_number: index + 1,
      )

    embeddings = [embedding_value + "0.000#{index}".to_f] * vector_def.dimensions
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
end
