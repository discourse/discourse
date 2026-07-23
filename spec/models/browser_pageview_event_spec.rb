# frozen_string_literal: true

RSpec.describe BrowserPageviewEvent do
  before do
    described_class.clear_queued!
    Discourse.clear_readonly!
  end

  after do
    described_class.clear_queued!
    Discourse.clear_readonly!
  end

  describe ".beacon_cutover_date" do
    it "returns the day after dashboard improvements was manually opted into" do
      SiteSetting.dashboard_improvements = true
      UpcomingChangeEvent.create!(
        upcoming_change_name: "dashboard_improvements",
        event_type: :manual_opt_in,
        created_at: Time.zone.local(2026, 5, 1, 10),
      )

      expect(described_class.beacon_cutover_date).to eq(Date.new(2026, 5, 2))
    end

    it "returns the day after dashboard improvements was automatically promoted" do
      SiteSetting.dashboard_improvements = true
      UpcomingChangeEvent.create!(
        upcoming_change_name: "dashboard_improvements",
        event_type: :automatically_promoted,
        created_at: Time.zone.local(2026, 5, 1, 10),
      )

      expect(described_class.beacon_cutover_date).to eq(Date.new(2026, 5, 2))
    end

    it "falls back to the site setting row when no enablement event exists" do
      SiteSetting.dashboard_improvements = true
      SiteSetting
        .stubs(:where)
        .with(name: "dashboard_improvements")
        .returns(stub(maximum: Time.zone.local(2026, 5, 1, 10)))

      expect(described_class.beacon_cutover_date).to eq(Date.new(2026, 5, 2))
    end

    it "uses the most recent enablement time across events and the setting row" do
      SiteSetting.dashboard_improvements = true
      UpcomingChangeEvent.create!(
        upcoming_change_name: "dashboard_improvements",
        event_type: :automatically_promoted,
        created_at: Time.zone.local(2026, 5, 1, 10),
      )
      SiteSetting
        .stubs(:where)
        .with(name: "dashboard_improvements")
        .returns(stub(maximum: Time.zone.local(2026, 5, 5, 10)))

      expect(described_class.beacon_cutover_date).to eq(Date.new(2026, 5, 6))
    end

    it "returns nil when dashboard improvements are disabled" do
      SiteSetting.dashboard_improvements = false

      expect(described_class.beacon_cutover_date).to be_nil
    end

    it "falls back to the first beacon counter date when no enablement record exists" do
      SiteSetting.dashboard_improvements = true
      Fabricate(:anonymous_browser_beacon_application_request, date: "2026-05-04", count: 2)
      Fabricate(:logged_in_browser_beacon_application_request, date: "2026-05-05", count: 1)

      expect(described_class.beacon_cutover_date).to eq(Date.new(2026, 5, 4))
    end

    it "returns nil when no beacons are collected" do
      SiteSetting.dashboard_improvements = true
      SiteSetting.trigger_browser_pageview_events = false
      SiteSetting.persist_browser_pageview_events = false
      UpcomingChangeEvent.create!(
        upcoming_change_name: "dashboard_improvements",
        event_type: :manual_opt_in,
      )

      expect(described_class.beacon_cutover_date).to be_nil
    end

    it "returns nil when legacy pageviews are enabled" do
      SiteSetting.use_legacy_pageviews = true
      SiteSetting.dashboard_improvements = true

      expect(described_class.beacon_cutover_date).to be_nil
    end
  end

  it "truncates string fields before saving" do
    event =
      described_class.create!(
        url: "a" * (described_class::MAX_URL_LENGTH + 1),
        referrer: "a" * (described_class::MAX_REFERRER_LENGTH + 1),
        user_agent: "a" * (described_class::MAX_USER_AGENT_LENGTH + 1),
        ip_address: "1.2.3.4",
        session_id: "a" * (described_class::MAX_SESSION_ID_LENGTH + 1),
        normalized_referrer: "a" * (described_class::MAX_NORMALIZED_REFERRER_LENGTH + 1),
      )

    expect(event.url.length).to eq(described_class::MAX_URL_LENGTH)
    expect(event.referrer.length).to eq(described_class::MAX_REFERRER_LENGTH)
    expect(event.user_agent.length).to eq(described_class::MAX_USER_AGENT_LENGTH)
    expect(event.session_id.length).to eq(described_class::MAX_SESSION_ID_LENGTH)
    expect(event.normalized_referrer.length).to eq(described_class::MAX_NORMALIZED_REFERRER_LENGTH)
  end

  describe ".flush_queued!" do
    let(:occurred_at) { Time.zone.parse("2026-05-27 10:30:00") }

    let(:payload) do
      {
        url: "https://discourse.example/t/topic/1",
        ip_address: "1.2.3.4",
        country_code: "AU",
        referrer: "https://www.example.com/path?utm_source=x",
        user_agent: "Mozilla/5.0",
        session_id: "xxxxxxxxxxxx4xxxyxxxxxxxxxxxxxxx",
        topic_id: 123,
        source: described_class::SOURCE_BEACON,
        occurred_at: occurred_at.iso8601(6),
      }
    end

    def queue_payload(payload)
      described_class.enqueue_for_later(payload)
    end

    it "queues payloads without flushing them synchronously" do
      expect { described_class.enqueue_for_later(payload) }.not_to change { described_class.count }

      expect(described_class.queued_count).to eq(1)
    end

    it "persists queued payloads and removes them from Redis" do
      described_class.enqueue_for_later(payload)

      expect { described_class.flush_queued! }.to change { described_class.count }.by(1)

      event = described_class.last
      expect(event.url).to eq(payload[:url])
      expect(event.country_code).to eq("AU")
      expect(event.normalized_referrer).to eq("example.com/path")
      expect(event.created_at).to eq_time(occurred_at)
      expect(event.source).to eq("beacon")
      expect(described_class.queued_count).to eq(0)
    end

    it "keeps queued payloads while PostgreSQL is readonly" do
      Discourse.stubs(:pg_readonly_mode?).returns(true)
      described_class.enqueue_for_later(payload)

      expect { described_class.flush_queued! }.not_to change { described_class.count }

      expect(described_class.queued_count).to eq(1)
    end

    it "discards invalid payloads without blocking later entries" do
      invalid_payload = payload.merge(occurred_at: "not-a-date")
      valid_payload = payload.merge(url: "https://discourse.example/t/topic/2")
      queue_payload(invalid_payload)
      queue_payload(valid_payload)

      expect { described_class.flush_queued! }.to change { described_class.count }.by(1)

      expect(described_class.last.url).to eq(valid_payload[:url])
      expect(described_class.queued_count).to eq(0)
    end

    it "removes malformed queued payloads without blocking later entries" do
      Discourse.redis.rpush(described_class::REDIS_QUEUE_KEY, "{")
      queue_payload(payload.merge(url: "https://discourse.example/t/topic/4"))

      expect { described_class.flush_queued! }.to change { described_class.count }.by(1)

      expect(described_class.last.url).to eq("https://discourse.example/t/topic/4")
      expect(described_class.queued_count).to eq(0)
    end
  end

  describe ".enqueue_for_later" do
    let(:payload) do
      {
        url: "https://discourse.example/t/topic/1",
        ip_address: "1.2.3.4",
        user_agent: "Mozilla/5.0",
        session_id: "xxxxxxxxxxxx4xxxyxxxxxxxxxxxxxxx",
        occurred_at: Time.zone.parse("2026-05-27 10:30:00").iso8601(6),
      }
    end

    it "skips payloads missing a required field instead of queueing them" do
      expect { described_class.enqueue_for_later(payload.except(:url)) }.not_to change {
        described_class.queued_count
      }
    end

    it "skips payloads with an unparseable IP address instead of queueing them" do
      expect {
        described_class.enqueue_for_later(payload.merge(ip_address: "1.2.3.4/64"))
      }.not_to change { described_class.queued_count }
    end

    it "drops new events once the queue reaches its maximum size" do
      stub_const(described_class, "REDIS_QUEUE_MAX_SIZE", 1) do
        described_class.enqueue_for_later(payload)
        expect { described_class.enqueue_for_later(payload) }.not_to change {
          described_class.queued_count
        }
      end

      expect(described_class.queued_count).to eq(1)
    end

    it "sets an expiry on the queue so a stranded backlog self-cleans" do
      described_class.enqueue_for_later(payload)

      expect(Discourse.redis.ttl(described_class::REDIS_QUEUE_KEY)).to be > 0
    end
  end
end
