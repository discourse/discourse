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

  it "stores fetched text as an upload and hands it to the existing RAG pipeline" do
    DiscourseAi::Rag::WebPageFetcher.stubs(:fetch).returns(
      not_modified: false,
      url: source.url,
      text: "A fixed knowledge-base answer.",
      etag: '"revision-1"',
      last_modified: "Wed, 19 Aug 2026 16:00:00 GMT",
    )

    expect { described_class.refresh(source) }.to change(Jobs::DigestRagUpload.jobs, :size).by(1)

    source.reload
    expect(source.upload).to be_present
    expect(source.last_fetched_at).to be_present
    expect(source.next_refresh_at).to be_within(1.minute).of(12.hours.from_now)
    expect(UploadReference.exists?(target: agent, upload_id: source.upload_id)).to eq(true)

    Jobs::DigestRagUpload.new.execute(
      upload_id: source.upload_id,
      target_id: agent.id,
      target_type: "AiAgent",
    )
    fragment = RagDocumentFragment.find_by!(target: agent, upload_id: source.upload_id)

    expect(fragment.fragment).to eq("A fixed knowledge-base answer.")
    expect(JSON.parse(fragment.metadata)).to eq("source_url" => source.url)
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
end
