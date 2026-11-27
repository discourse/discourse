# frozen_string_literal: true

RSpec.describe RagDocumentSource do
  fab!(:agent, :ai_agent)

  before { enable_current_plugin }

  it "defaults the refresh interval to 24 hours" do
    source = described_class.create!(target: agent, url: "https://example.com/guide")

    expect(source.refresh_interval_hours).to eq(24)
  end

  it "normalizes URLs and queues the initial refresh" do
    expect {
      source =
        described_class.create!(
          target: agent,
          url: "https://example.com/guide#installation",
          refresh_interval_hours: 12,
        )

      expect(source.url).to eq("https://example.com/guide")
    }.to change(Jobs::RefreshRagDocumentSource.jobs, :size).by(1)
  end

  it "only accepts HTTP URLs that FinalDestination allows, without embedded credentials" do
    invalid_urls = %w[
      file:///etc/passwd
      https://user:password@example.com/private
      https://example.com:8443/guide
      https://1.2.3.4/guide
    ]

    accepted = invalid_urls.select { |url| described_class.new(target: agent, url: url).valid? }

    expect(accepted).to be_empty
  end

  it "removes active and pending indexed content when the source is deleted" do
    upload = Fabricate(:upload)
    pending_upload = Fabricate(:upload)
    source =
      described_class.create!(
        target: agent,
        url: "https://example.com/docs",
        upload: upload,
        pending_upload: pending_upload,
      )
    fragment = Fabricate(:rag_document_fragment, target: agent, upload: upload)
    pending_fragment = Fabricate(:rag_document_fragment, target: agent, upload: pending_upload)
    UploadReference.ensure_exist!(target: agent, upload_ids: [upload.id, pending_upload.id])

    source.destroy!

    expect(RagDocumentFragment.exists?(fragment.id)).to eq(false)
    expect(RagDocumentFragment.exists?(pending_fragment.id)).to eq(false)
    expect(UploadReference.exists?(target: agent, upload_id: [upload.id, pending_upload.id])).to eq(
      false,
    )
  end
end
