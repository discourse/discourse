# frozen_string_literal: true

RSpec.describe DiscourseAi::Rag::DocumentSourceRefresher do
  fab!(:agent, :ai_agent)
  fab!(:embedding_definition)

  let(:source) do
    RagDocumentSource.create!(
      target: agent,
      url: "https://example.com/knowledge",
      refresh_interval_hours: 12,
    )
  end

  before do
    enable_current_plugin
    SiteSetting.ai_embeddings_selected_model = embedding_definition.id
    SiteSetting.ai_embeddings_enabled = true
  end

  it "keeps existing knowledge active until the fetched replacement is indexed" do
    old_upload = Fabricate(:upload)
    old_fragment = Fabricate(:rag_document_fragment, target: agent, upload: old_upload)
    UploadReference.ensure_exist!(target: agent, upload_ids: [old_upload.id])
    source.update_columns(upload_id: old_upload.id)
    DiscourseAi::Rag::WebPageFetcher.stubs(:fetch).returns(
      not_modified: false,
      url: source.url,
      text: "A fixed knowledge-base answer.",
      etag: '"revision-1"',
      last_modified: "Wed, 19 Aug 2026 16:00:00 GMT",
    )

    expect { described_class.refresh(source) }.to change(Jobs::DigestRagUpload.jobs, :size).by(1)

    source.reload
    pending_upload = source.pending_upload
    expect(source.upload_id).to eq(old_upload.id)
    expect(pending_upload).to be_present
    expect(source.last_fetched_at).to be_present
    expect(source.next_refresh_at).to be_within(1.minute).of(12.hours.from_now)
    expect(RagDocumentFragment.exists?(old_fragment.id)).to eq(true)
    expect(UploadReference.exists?(target: agent, upload_id: pending_upload.id)).to eq(false)

    Jobs::DigestRagUpload.new.execute(
      upload_id: pending_upload.id,
      target_id: agent.id,
      target_type: "AiAgent",
    )
    fragments = RagDocumentFragment.where(target: agent, upload_id: pending_upload.id)
    fragment = fragments.first

    expected_embedding = [0.0038493] * embedding_definition.dimensions
    stub_request(:post, embedding_definition.url).to_return(
      status: 200,
      body: JSON.dump(expected_embedding),
    )
    Jobs::GenerateRagEmbeddings.new.execute(fragment_ids: fragments.pluck(:id))

    source.reload

    expect(fragment.fragment).to eq("A fixed knowledge-base answer.")
    expect(JSON.parse(fragment.metadata)).to eq("source_url" => source.url)
    expect(source.upload_id).to eq(pending_upload.id)
    expect(source.pending_upload_id).to be_nil
    expect(RagDocumentFragment.exists?(old_fragment.id)).to eq(false)
    expect(UploadReference.exists?(target: agent, upload_id: pending_upload.id)).to eq(true)
  end

  it "retains existing content and retries later when refresh fails" do
    upload = Fabricate(:upload)
    source.update_columns(upload_id: upload.id)
    DiscourseAi::Rag::WebPageFetcher.stubs(:fetch).raises(
      DiscourseAi::Rag::WebPageFetcher::FetchError,
      "upstream unavailable",
    )

    described_class.refresh(source)

    source.reload
    expect(source.upload_id).to eq(upload.id)
    expect(source.last_error).to eq("upstream unavailable")
    expect(source.next_refresh_at).to be_within(1.minute).of(1.hour.from_now)
  end

  it "records an actionable retry when the selected embedding model is invalid" do
    SiteSetting.ai_embeddings_selected_model = -1

    described_class.refresh(source)

    source.reload
    expect(source.pending_upload_id).to be_nil
    expect(source.last_error).to eq("Invalid embeddings selected model")
    expect(source.next_refresh_at).to be_within(1.minute).of(1.hour.from_now)
  end

  it "refetches the full document when a staged upload has disappeared" do
    missing_upload_id = Upload.maximum(:id).to_i + 10_000
    source.update_columns(pending_upload_id: missing_upload_id, etag: '"revision-1"')
    DiscourseAi::Rag::WebPageFetcher.stubs(:fetch).returns(not_modified: true)

    described_class.refresh(source)

    source.reload
    expect(source.pending_upload_id).to be_nil
    expect(source.etag).to be_nil
    expect(source.last_error).to eq("The pending upload is unavailable")
    expect(source.next_refresh_at).to be_within(1.minute).of(1.hour.from_now)
  end
end
