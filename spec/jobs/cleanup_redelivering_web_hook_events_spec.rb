# frozen_string_literal: true

RSpec.describe Jobs::CleanupRedeliveringWebHookEvents do
  subject(:job) { described_class.new }

  fab!(:redelivering_webhook_event1) do
    Fabricate(:redelivering_webhook_event, created_at: Time.now)
  end

  fab!(:redelivering_webhook_event2) do
    Fabricate(:redelivering_webhook_event, created_at: 9.hours.ago)
  end

  it "deletes redelivering_webhook_events that created more than 8 hours ago" do
    job.execute({})
    expect(RedeliveringWebhookEvent.count).to eq(1)
    expect(RedeliveringWebhookEvent.find_by(id: redelivering_webhook_event1.id)).to be_present
  end
end
