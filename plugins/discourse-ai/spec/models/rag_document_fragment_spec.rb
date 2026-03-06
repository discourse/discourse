# frozen_string_literal: true

RSpec.describe RagDocumentFragment do
  fab!(:agent, :ai_agent)
  fab!(:upload_1, :upload)
  fab!(:upload_2, :upload)
  fab!(:vector_def, :embedding_definition)

  before do
    enable_current_plugin
    SiteSetting.ai_embeddings_selected_model = vector_def.id
    SiteSetting.ai_embeddings_enabled = true
  end

  describe ".link_uploads_and_agent" do
    it "does nothing if there is no agent" do
      expect { described_class.link_target_and_uploads(nil, [upload_1.id]) }.not_to change(
        Jobs::DigestRagUpload.jobs,
        :size,
      )
    end

    it "does nothing if there are no uploads" do
      expect { described_class.link_target_and_uploads(agent, []) }.not_to change(
        Jobs::DigestRagUpload.jobs,
        :size,
      )
    end

    it "queues a job for each upload to generate fragments" do
      expect {
        described_class.link_target_and_uploads(agent, [upload_1.id, upload_2.id])
      }.to change(Jobs::DigestRagUpload.jobs, :size).by(2)
    end

    it "creates references between the agent an each upload" do
      described_class.link_target_and_uploads(agent, [upload_1.id, upload_2.id])

      refs = UploadReference.where(target: agent).pluck(:upload_id)

      expect(refs).to contain_exactly(upload_1.id, upload_2.id)
    end
  end

  describe ".update_target_uploads" do
    it "does nothing if there is no agent" do
      expect { described_class.update_target_uploads(nil, [upload_1.id]) }.not_to change(
        Jobs::DigestRagUpload.jobs,
        :size,
      )
    end

    it "deletes the fragment if its not present in the uploads list" do
      fragment = Fabricate(:rag_document_fragment, target: agent)

      described_class.update_target_uploads(agent, [])

      expect { fragment.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "delete references between the upload and the agent" do
      described_class.link_target_and_uploads(agent, [upload_1.id, upload_2.id])
      described_class.update_target_uploads(agent, [upload_2.id])

      refs = UploadReference.where(target: agent).pluck(:upload_id)

      expect(refs).to contain_exactly(upload_2.id)
    end

    it "queues jobs to generate new fragments" do
      expect { described_class.update_target_uploads(agent, [upload_1.id]) }.to change(
        Jobs::DigestRagUpload.jobs,
        :size,
      ).by(1)
    end
  end

  describe ".indexing_status" do
    let(:vector) { DiscourseAi::Embeddings::Vector.instance }

    let(:rag_document_fragment_1) do
      Fabricate(:rag_document_fragment, upload: upload_1, target: agent)
    end

    let(:rag_document_fragment_2) do
      Fabricate(:rag_document_fragment, upload: upload_1, target: agent)
    end

    let(:expected_embedding) { [0.0038493] * vector_def.dimensions }

    before do
      SiteSetting.ai_embeddings_selected_model = vector_def.id
      rag_document_fragment_1
      rag_document_fragment_2

      WebMock.stub_request(:post, "https://test.com/embeddings").to_return(
        status: 200,
        body: JSON.dump(expected_embedding),
      )

      vector.generate_representation_from(rag_document_fragment_1)
    end

    it "regenerates all embeddings if ai_embeddings_selected_model changes" do
      old_id = rag_document_fragment_1.id

      UploadReference.create!(upload_id: upload_1.id, target: agent)
      UploadReference.create!(upload_id: upload_2.id, target: agent)

      Sidekiq::Testing.fake! do
        SiteSetting.ai_embeddings_selected_model = Fabricate(:open_ai_embedding_def).id
        expect(RagDocumentFragment.exists?(old_id)).to eq(false)
        expect(Jobs::DigestRagUpload.jobs.size).to eq(2)
      end
    end

    it "returns total, indexed and unindexed fragments for each upload" do
      results = described_class.indexing_status(agent, [upload_1, upload_2])

      upload_1_status = results[upload_1.id]
      expect(upload_1_status[:total]).to eq(2)
      expect(upload_1_status[:indexed]).to eq(1)
      expect(upload_1_status[:left]).to eq(1)

      upload_1_status = results[upload_2.id]
      expect(upload_1_status[:total]).to eq(0)
      expect(upload_1_status[:indexed]).to eq(0)
      expect(upload_1_status[:left]).to eq(0)
    end
  end
end
