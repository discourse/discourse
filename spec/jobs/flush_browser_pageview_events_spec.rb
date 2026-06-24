# frozen_string_literal: true

RSpec.describe Jobs::FlushBrowserPageviewEvents do
  before do
    BrowserPageviewEvent.clear_queued!
    Discourse.clear_readonly!
  end

  after do
    BrowserPageviewEvent.clear_queued!
    Discourse.clear_readonly!
  end

  let(:payload) do
    {
      url: "https://discourse.example/t/topic/1",
      ip_address: "1.2.3.4",
      user_agent: "Mozilla/5.0",
      session_id: "xxxxxxxxxxxx4xxxyxxxxxxxxxxxxxxx",
      source: BrowserPageviewEvent::SOURCE_BEACON,
      occurred_at: Time.zone.parse("2026-05-27 10:30:00").iso8601(6),
    }
  end

  def queue_payload(payload)
    BrowserPageviewEvent.enqueue_for_later(payload)
  end

  def queue_payloads(payloads)
    payloads.each { |queued_payload| queue_payload(queued_payload) }
  end

  it "does nothing when browser pageview persistence is disabled" do
    SiteSetting.persist_browser_pageview_events = false
    queue_payload(payload)

    expect { described_class.new.execute({}) }.not_to change { BrowserPageviewEvent.count }

    expect(BrowserPageviewEvent.queued_count).to eq(1)
  end

  it "flushes queued browser pageviews" do
    SiteSetting.persist_browser_pageview_events = true
    queue_payload(payload)

    expect { described_class.new.execute({}) }.to change { BrowserPageviewEvent.count }.by(1)

    expect(BrowserPageviewEvent.queued_count).to eq(0)
  end

  it "flushes multiple batches in one run" do
    SiteSetting.persist_browser_pageview_events = true

    stub_const(BrowserPageviewEvent, "REDIS_FLUSH_BATCH_SIZE", 3) do
      payloads = 5.times.map { |index| payload.merge(session_id: format("%032d", index)) }
      queue_payloads(payloads)

      expect { described_class.new.execute({}) }.to change { BrowserPageviewEvent.count }.by(
        payloads.length,
      )

      expect(BrowserPageviewEvent.queued_count).to eq(0)
    end
  end
end
