# frozen_string_literal: true

RSpec.describe Jobs::RefreshRagDocumentSources do
  fab!(:agent, :ai_agent)

  before { enable_current_plugin }

  it "queues only sources whose refresh time is due" do
    due_source =
      RagDocumentSource.create!(target: agent, url: "https://example.com/due", next_refresh_at: nil)
    future_source = RagDocumentSource.create!(target: agent, url: "https://example.com/future")
    future_source.update_columns(next_refresh_at: 2.hours.from_now)
    Jobs::RefreshRagDocumentSource.jobs.clear

    described_class.new.execute({})

    queued_ids =
      Jobs::RefreshRagDocumentSource.jobs.map { |job| job["args"].first["rag_document_source_id"] }
    expect(queued_ids).to contain_exactly(due_source.id)
    expect(queued_ids).not_to include(future_source.id)
  end
end
