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
        asn: 12_345,
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
      expect(event.asn).to eq(12_345)
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

  describe ".beacon_rollup_start_date" do
    def record_enablement(event_type, created_at)
      UpcomingChangeEvent.create!(
        upcoming_change_name: "dashboard_improvements",
        event_type:,
        created_at:,
      )
    end

    it "is nil when dashboard_improvements is disabled" do
      SiteSetting.dashboard_improvements = false
      record_enablement(:manual_opt_in, 2.days.ago)

      expect(described_class.beacon_rollup_start_date).to be_nil
    end

    it "is nil when the change is enabled but no enablement event was recorded" do
      SiteSetting.dashboard_improvements = true

      expect(described_class.beacon_rollup_start_date).to be_nil
    end

    it "is the day after the change was manually enabled" do
      SiteSetting.dashboard_improvements = true
      record_enablement(:manual_opt_in, Time.zone.parse("2026-07-10 15:00"))

      expect(described_class.beacon_rollup_start_date).to eq(Date.new(2026, 7, 11))
    end

    it "is the day after an automatic promotion" do
      SiteSetting.dashboard_improvements = true
      record_enablement(:automatically_promoted, Time.zone.parse("2026-07-10 15:00"))

      expect(described_class.beacon_rollup_start_date).to eq(Date.new(2026, 7, 11))
    end

    it "uses the latest enablement when the change was toggled off and on again" do
      SiteSetting.dashboard_improvements = true
      record_enablement(:manual_opt_in, Time.zone.parse("2026-07-01 09:00"))
      record_enablement(:manual_opt_out, Time.zone.parse("2026-07-05 09:00"))
      record_enablement(:manual_opt_in, Time.zone.parse("2026-07-10 09:00"))

      expect(described_class.beacon_rollup_start_date).to eq(Date.new(2026, 7, 11))
    end
  end

  describe ".rollup_source_for" do
    it "is piggyback for every date when there is no cutover" do
      SiteSetting.dashboard_improvements = false

      expect(described_class.rollup_source_for(Time.zone.today)).to eq(
        described_class::SOURCE_PIGGYBACK,
      )
    end

    it "flips from piggyback to beacon at the cutover date" do
      SiteSetting.dashboard_improvements = true
      UpcomingChangeEvent.create!(
        upcoming_change_name: "dashboard_improvements",
        event_type: :manual_opt_in,
        created_at: Time.zone.parse("2026-07-10 15:00"),
      )

      expect(described_class.rollup_source_for(Date.new(2026, 7, 10))).to eq(
        described_class::SOURCE_PIGGYBACK,
      )
      expect(described_class.rollup_source_for(Date.new(2026, 7, 11))).to eq(
        described_class::SOURCE_BEACON,
      )
    end
  end
end
