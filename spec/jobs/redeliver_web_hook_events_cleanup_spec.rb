# frozen_string_literal: true

require "excon"

RSpec.describe Jobs::RedeliverWebHookEventsCleanup do
  subject(:job) { described_class.new }

  fab!(:web_hook)
  fab!(:web_hook_event1) { Fabricate(:web_hook_event, web_hook: web_hook) }
  fab!(:web_hook_event2) { Fabricate(:web_hook_event, web_hook: web_hook) }

  fab!(:redelivering_webhook_event1) do
    Fabricate(
      :redelivering_webhook_event,
      web_hook_event_id: web_hook_event1.id,
      created_at: Time.now,
    )
  end

  fab!(:redelivering_webhook_event2) do
    Fabricate(
      :redelivering_webhook_event,
      web_hook_event_id: web_hook_event2.id,
      created_at: 9.hours.ago,
    )
  end

  it "deletes redelivering_webhook_events that created more than 8 hours ago" do
    job.execute(web_hook: web_hook)
    expect(RedeliveringWebhookEvent.count).to eq(1)
  end
end
