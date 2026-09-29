# frozen_string_literal: true

RSpec.describe BrowserPageviewSessionRollupSummary do
  describe ".refresh_recent!" do
    let(:today) { Time.zone.today }
    let(:yesterday) { today - 1 }

    def refresh
      described_class.refresh_recent!(start_date: yesterday, end_date: today)
    end

    it "replaces recent daily totals after pageview, score, and engagement changes" do
      event = Fabricate(:browser_pageview_event, created_at: yesterday.to_time(:utc) + 12.hours)
      Fabricate(
        :browser_pageview_session_engagement,
        session_id: event.session_id,
        engaged_seconds: 4,
      )

      refresh

      expect(
        BrowserPageviewSessionEngagementDailyRollup.where(date: yesterday).pick(
          :sessions,
          :bounced,
        ),
      ).to eq([1, 1])

      user = Fabricate(:user)
      Fabricate(
        :browser_pageview_event,
        session_id: event.session_id,
        user_id: user.id,
        score: CrawlerScorer::BOT_SCORE_THRESHOLD + 1,
        created_at: today.to_time(:utc) + 1.hour,
      )
      BrowserPageviewSessionEngagement.upsert_from_payload(
        session_id: event.session_id,
        mouse_move_events: 0,
        click_events: 0,
        key_events: 0,
        scroll_events: 0,
        touch_events: 0,
        back_forward_events: 0,
        engaged_seconds: 22,
        time_to_first_interaction_ms: nil,
      )

      refresh

      expect(
        BrowserPageviewSessionEngagementDailyRollup.where(date: yesterday).pick(
          :sessions,
          :bounced,
          :engaged_seconds_total,
          :likely_crawler_sessions,
          :logged_in,
        ),
      ).to eq([1, 0, 22, 1, true])
      expect(BrowserPageviewSessionEngagementDailyRollup.where(date: today).count).to eq(0)
      expect(described_class.find(event.session_id).dirty_generation).to eq(
        described_class.find(event.session_id).refreshed_generation,
      )
    end

    it "keeps historical rows and retries an interrupted initialization" do
      old_row =
        Fabricate(:browser_pageview_session_engagement_daily_rollup, date: today - 15, sessions: 17)
      Fabricate(:browser_pageview_event, created_at: yesterday.to_time(:utc) + 11.hours)
      allow(DB).to receive(:exec).and_wrap_original do |method, sql, **params|
        if sql.include?("INSERT INTO browser_pageview_session_engagement_daily_rollups")
          raise "interrupted"
        end

        method.call(sql, **params)
      end

      expect { refresh }.to raise_error("interrupted")
      expect(BrowserPageviewSessionEngagementDailyRollup.where(date: yesterday)).to be_empty
      expect(described_class.initialized?).to eq(false)

      allow(DB).to receive(:exec).and_call_original
      refresh
      refresh

      expect(
        BrowserPageviewSessionEngagementDailyRollup.where(date: yesterday).sum(:sessions),
      ).to eq(1)
      expect(old_row.reload.sessions).to eq(17)
      expect(described_class.initialized?).to eq(true)
    end

    it "keeps the previous whole daily row when replacement fails" do
      Fabricate(:browser_pageview_event, created_at: yesterday.to_time(:utc) + 8.hours)
      refresh
      Fabricate(:browser_pageview_event, created_at: yesterday.to_time(:utc) + 9.hours)
      allow(DB).to receive(:exec).and_wrap_original do |method, sql, **params|
        if sql.include?("INSERT INTO browser_pageview_session_engagement_daily_rollups")
          raise "interrupted"
        end

        method.call(sql, **params)
      end

      expect { refresh }.to raise_error("interrupted")
      expect(
        BrowserPageviewSessionEngagementDailyRollup.where(date: yesterday).sum(:sessions),
      ).to eq(1)

      allow(DB).to receive(:exec).and_call_original
      refresh

      expect(
        BrowserPageviewSessionEngagementDailyRollup.where(date: yesterday).sum(:sessions),
      ).to eq(2)
    end

    it "repairs both older dates when a pending session moves during an outage" do
      first_date = today - 5
      earlier_date = today - 6
      event = Fabricate(:browser_pageview_event, created_at: first_date.to_time(:utc) + 12.hours)
      Fabricate(:browser_pageview_session_engagement_daily_rollup, date: first_date, sessions: 1)
      described_class.refresh_recent!(start_date: first_date, end_date: first_date)
      Fabricate(
        :browser_pageview_event,
        session_id: event.session_id,
        created_at: earlier_date.to_time(:utc) + 12.hours,
      )

      refresh

      expect(
        BrowserPageviewSessionEngagementDailyRollup.where(date: first_date).sum(:sessions),
      ).to eq(0)
      expect(
        BrowserPageviewSessionEngagementDailyRollup.where(date: earlier_date).sum(:sessions),
      ).to eq(1)
    end

    it "removes an older daily row when its final retained pageview is deleted" do
      date = today - 3
      event = Fabricate(:browser_pageview_event, created_at: date.to_time(:utc) + 8.hours)
      described_class.refresh_recent!(start_date: date, end_date: date)
      expect(BrowserPageviewSessionEngagementDailyRollup.where(date:).sum(:sessions)).to eq(1)

      event.delete
      refresh

      expect(BrowserPageviewSessionEngagementDailyRollup.where(date:).sum(:sessions)).to eq(0)
    end

    it "does not dirty sessions when old source records are removed by retention" do
      event = Fabricate(:browser_pageview_event, created_at: 4.months.ago)
      described_class.where(session_id: event.session_id).update_all(
        dirty_generation: 1,
        refreshed_generation: 1,
      )

      event.delete

      expect(described_class.find(event.session_id).dirty_generation).to eq(1)
    end

    it "reclassifies a session after its crawler score changes in either direction" do
      event = Fabricate(:browser_pageview_event, created_at: yesterday.to_time(:utc) + 9.hours)
      refresh

      event.update!(score: CrawlerScorer::BOT_SCORE_THRESHOLD + 1)
      refresh
      expect(
        BrowserPageviewSessionEngagementDailyRollup.where(date: yesterday).sum(
          :likely_crawler_sessions,
        ),
      ).to eq(1)

      event.update!(score: 0)
      refresh
      expect(
        BrowserPageviewSessionEngagementDailyRollup.where(date: yesterday).sum(
          :likely_crawler_sessions,
        ),
      ).to eq(0)
    end

    it "tracks sessions inserted through the queued pageview bulk path" do
      rows =
        2.times.map do
          {
            url: "/",
            ip_address: "127.0.0.1",
            user_agent: "spec",
            session_id: SecureRandom.hex(16),
            created_at: yesterday.to_time(:utc) + 8.hours,
          }
        end
      BrowserPageviewEvent.insert_all(rows, returning: false)

      refresh

      expect(
        BrowserPageviewSessionEngagementDailyRollup.where(date: yesterday).sum(:sessions),
      ).to eq(2)
    end

    it "matches the source aggregation for recent sessions and excludes older starts" do
      anonymous = Fabricate(:browser_pageview_event, created_at: yesterday.to_time(:utc) + 8.hours)
      user = Fabricate(:user)
      logged_in =
        Fabricate(
          :browser_pageview_event,
          user_id: user.id,
          score: CrawlerScorer::BOT_SCORE_THRESHOLD + 1,
          created_at: yesterday.to_time(:utc) + 9.hours,
        )
      Fabricate(
        :browser_pageview_event,
        session_id: logged_in.session_id,
        created_at: today.to_time(:utc) + 1.hour,
      )
      Fabricate(
        :browser_pageview_session_engagement,
        session_id: anonymous.session_id,
        engaged_seconds: 12,
      )
      older =
        Fabricate(:browser_pageview_event, created_at: (yesterday - 1).to_time(:utc) + 9.hours)
      Fabricate(
        :browser_pageview_event,
        session_id: older.session_id,
        created_at: yesterday.to_time(:utc) + 9.hours,
      )

      refresh
      incremental_totals =
        BrowserPageviewSessionEngagementDailyRollup.order(:date, :logged_in).pluck(
          :date,
          :logged_in,
          :sessions,
          :bounced,
          :engaged_seconds_total,
          :likely_crawler_sessions,
          :likely_crawler_bounced,
          :likely_crawler_engaged_seconds_total,
        )
      BrowserPageviewSessionEngagementDailyRollup.aggregate(start_date: yesterday, end_date: today)

      expect(
        BrowserPageviewSessionEngagementDailyRollup.order(:date, :logged_in).pluck(
          :date,
          :logged_in,
          :sessions,
          :bounced,
          :engaged_seconds_total,
          :likely_crawler_sessions,
          :likely_crawler_bounced,
          :likely_crawler_engaged_seconds_total,
        ),
      ).to eq(incremental_totals)
    end
  end

  describe ".verify_recent!" do
    it "raises when clean summary values differ from retained source records" do
      date = 2.days.ago.to_date
      event = Fabricate(:browser_pageview_event, created_at: date.to_time(:utc) + 8.hours)
      described_class.refresh_recent!(start_date: date, end_date: date)

      expect { described_class.verify_recent!(date:) }.not_to raise_error

      described_class.where(session_id: event.session_id).update_all(pageview_count: 99)

      expect { described_class.verify_recent!(date:) }.to raise_error(
        /Browser pageview session rollup differs from source/,
      )
    end

    it "detects a clean summary whose source session no longer exists" do
      date = 2.days.ago.to_date
      Fabricate(:browser_pageview_event, created_at: date.to_time(:utc) + 8.hours)
      described_class.refresh_recent!(start_date: date, end_date: date)
      described_class.create!(
        session_id: SecureRandom.hex(16),
        first_pageview_at: date.to_time(:utc) + 9.hours,
        pageview_count: 1,
        dirty_generation: 1,
        refreshed_generation: 1,
      )

      expect { described_class.verify_recent!(date:) }.to raise_error(
        /Browser pageview session rollup differs from source/,
      )
    end
  end
end
