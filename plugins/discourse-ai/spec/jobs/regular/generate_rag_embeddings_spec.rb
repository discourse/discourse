# frozen_string_literal: true

RSpec.describe Jobs::GenerateRagEmbeddings do
  subject(:job) { described_class.new }

  before { enable_current_plugin }

  describe "#execute" do
    fab!(:vector_def, :embedding_definition)

    let(:expected_embedding) { [0.0038493] * vector_def.dimensions }

    fab!(:ai_agent)

    let(:rag_document_fragment_1) { Fabricate(:rag_document_fragment, target: ai_agent) }
    let(:rag_document_fragment_2) { Fabricate(:rag_document_fragment, target: ai_agent) }

    before do
      SiteSetting.ai_embeddings_selected_model = vector_def.id
      SiteSetting.ai_embeddings_enabled = true

      rag_document_fragment_1
      rag_document_fragment_2

      WebMock.stub_request(:post, vector_def.url).to_return(
        status: 200,
        body: JSON.dump(expected_embedding),
      )
    end

    it "generates a new vector for each fragment" do
      expected_embeddings = 2

      job.execute(fragment_ids: [rag_document_fragment_1.id, rag_document_fragment_2.id])

      embeddings_count =
        DB.query_single(
          "SELECT COUNT(*) from #{DiscourseAi::Embeddings::Schema::RAG_DOCS_TABLE}",
        ).first

      expect(embeddings_count).to eq(expected_embeddings)
    end

    it "records a retryable failure for a staged URL source" do
      source =
        RagDocumentSource.create!(
          target: ai_agent,
          url: "https://example.com/knowledge",
          pending_upload: rag_document_fragment_1.upload,
        )
      SiteSetting.ai_embeddings_selected_model = -1

      expect { job.execute(fragment_ids: [rag_document_fragment_1.id]) }.to raise_error(
        "Invalid embeddings selected model",
      )

      source.reload
      expect(source.last_error).to eq("Invalid embeddings selected model")
      expect(source.next_refresh_at).to be_within(1.minute).of(1.hour.from_now)
    end

    describe "Publishing progress updates" do
      it "sends an update through mb after a batch finishes" do
        updates =
          MessageBus.track_publish("/discourse-ai/rag/#{rag_document_fragment_1.upload_id}") do
            job.execute(fragment_ids: [rag_document_fragment_1.id])
          end

        upload_index_stats = updates.last.data

        expect(upload_index_stats[:total]).to eq(1)
        expect(upload_index_stats[:indexed]).to eq(1)
        expect(upload_index_stats[:left]).to eq(0)
      end
    end
  end
end
