# frozen_string_literal: true

RSpec.describe BrowserPageviewSessionEngagementDailyRollup do
  describe ".aggregate" do
    let(:start_date) { Date.new(2026, 6, 1) }
    let(:end_date) { Date.new(2026, 6, 30) }

    before { freeze_time(Time.utc(2026, 6, 20, 12, 0, 0)) }

    it "bounces a single-pageview session with fewer than 10 engaged seconds" do
      event = Fabricate(:browser_pageview_event, created_at: Time.utc(2026, 6, 10, 9))
      Fabricate(
        :browser_pageview_session_engagement,
        session_id: event.session_id,
        engaged_seconds: 9,
      )

      described_class.aggregate(start_date:, end_date:)

      expect(described_class.all).to contain_exactly(have_attributes(sessions: 1, bounced: 1))
    end

    it "bounces a single-pageview session that has no engagement row" do
      Fabricate(:browser_pageview_event, created_at: Time.utc(2026, 6, 10, 9))

      described_class.aggregate(start_date:, end_date:)

      expect(described_class.all).to contain_exactly(
        have_attributes(sessions: 1, bounced: 1, engaged_seconds_total: 0),
      )
    end

    it "does not bounce a single-pageview session with 10 or more engaged seconds" do
      event = Fabricate(:browser_pageview_event, created_at: Time.utc(2026, 6, 10, 9))
      Fabricate(
        :browser_pageview_session_engagement,
        session_id: event.session_id,
        engaged_seconds: 10,
      )

      described_class.aggregate(start_date:, end_date:)

      expect(described_class.all).to contain_exactly(have_attributes(sessions: 1, bounced: 0))
    end

    it "does not bounce a multi-pageview session even with fewer than 10 engaged seconds" do
      event = Fabricate(:browser_pageview_event, created_at: Time.utc(2026, 6, 10, 9, 0))
      Fabricate(
        :browser_pageview_event,
        session_id: event.session_id,
        created_at: Time.utc(2026, 6, 10, 9, 1),
      )
      Fabricate(
        :browser_pageview_session_engagement,
        session_id: event.session_id,
        engaged_seconds: 2,
      )

      described_class.aggregate(start_date:, end_date:)

      expect(described_class.all).to contain_exactly(
        have_attributes(sessions: 1, bounced: 0, engaged_seconds_total: 2),
      )
    end

    it "does not bounce a multi-pageview session that has no engagement row" do
      event = Fabricate(:browser_pageview_event, created_at: Time.utc(2026, 6, 10, 9, 0))
      Fabricate(
        :browser_pageview_event,
        session_id: event.session_id,
        created_at: Time.utc(2026, 6, 10, 9, 1),
      )

      described_class.aggregate(start_date:, end_date:)

      expect(described_class.all).to contain_exactly(have_attributes(sessions: 1, bounced: 0))
    end

    it "does not bounce a session whose second pageview falls past the range end" do
      freeze_time(Time.utc(2026, 7, 15, 12, 0, 0))
      event = Fabricate(:browser_pageview_event, created_at: Time.utc(2026, 6, 30, 23, 30))
      Fabricate(
        :browser_pageview_event,
        session_id: event.session_id,
        created_at: Time.utc(2026, 7, 1, 0, 30),
      )

      described_class.aggregate(start_date:, end_date:)

      expect(described_class.all).to contain_exactly(have_attributes(sessions: 1, bounced: 0))
    end

    it "splits sessions and bounced counts by the session's logged-in state" do
      user = Fabricate(:user)
      Fabricate(:browser_pageview_event, user_id: user.id, created_at: Time.utc(2026, 6, 10, 9))
      Fabricate(:browser_pageview_event, created_at: Time.utc(2026, 6, 10, 9))

      described_class.aggregate(start_date:, end_date:)

      rows =
        described_class.order(:logged_in).pluck(
          :logged_in,
          :sessions,
          :bounced,
          :engaged_seconds_total,
        )
      expect(rows).to eq([[false, 1, 1, 0], [true, 1, 1, 0]])
    end

    it "attributes a session spanning UTC midnight to its first pageview's UTC date" do
      event = Fabricate(:browser_pageview_event, created_at: Time.utc(2026, 6, 10, 23, 30))
      Fabricate(
        :browser_pageview_event,
        session_id: event.session_id,
        created_at: Time.utc(2026, 6, 11, 0, 30),
      )
      Fabricate(
        :browser_pageview_session_engagement,
        session_id: event.session_id,
        engaged_seconds: 42,
      )

      described_class.aggregate(start_date:, end_date:)

      expect(described_class.pluck(:date)).to eq([Date.new(2026, 6, 10)])
    end

    it "sums engaged seconds per date and logged-in state" do
      user = Fabricate(:user)
      anon_event = Fabricate(:browser_pageview_event, created_at: Time.utc(2026, 6, 10, 9))
      logged_in_event =
        Fabricate(:browser_pageview_event, user_id: user.id, created_at: Time.utc(2026, 6, 10, 9))
      Fabricate(
        :browser_pageview_session_engagement,
        session_id: anon_event.session_id,
        engaged_seconds: 30,
      )
      Fabricate(
        :browser_pageview_session_engagement,
        session_id: logged_in_event.session_id,
        engaged_seconds: 70,
      )

      described_class.aggregate(start_date:, end_date:)

      totals = described_class.order(:logged_in).pluck(:logged_in, :engaged_seconds_total)
      expect(totals).to eq([[false, 30], [true, 70]])
    end

    it "excludes engagement rows whose session has no pageview events" do
      Fabricate(:browser_pageview_session_engagement, engaged_seconds: 120)

      described_class.aggregate(start_date:, end_date:)

      expect(described_class.count).to eq(0)
    end

    it "counts only rollup-source pageviews, even within a single session" do
      SiteSetting.dashboard_improvements = true
      UpcomingChangeEvent.create!(
        upcoming_change_name: "dashboard_improvements",
        event_type: :manual_opt_in,
        created_at: Time.utc(2026, 6, 1, 9),
      )
      beacon_event =
        Fabricate(:browser_pageview_event, source: :beacon, created_at: Time.utc(2026, 6, 10, 9))
      Fabricate(
        :browser_pageview_event,
        session_id: beacon_event.session_id,
        source: :piggyback,
        created_at: Time.utc(2026, 6, 10, 10),
      )
      Fabricate(:browser_pageview_event, source: :piggyback, created_at: Time.utc(2026, 6, 10, 9))

      described_class.aggregate(start_date:, end_date:)

      expect(described_class.all).to contain_exactly(have_attributes(sessions: 1, bounced: 1))
    end

    it "clears a session's previous logged-in partition when it flips across runs" do
      event = Fabricate(:browser_pageview_event, created_at: Time.utc(2026, 6, 10, 9))
      described_class.aggregate(start_date:, end_date:)

      user = Fabricate(:user)
      Fabricate(
        :browser_pageview_event,
        session_id: event.session_id,
        user_id: user.id,
        created_at: Time.utc(2026, 6, 10, 10),
      )
      described_class.aggregate(start_date:, end_date:)

      expect(described_class.all).to contain_exactly(have_attributes(logged_in: true, sessions: 1))
    end

    it "keeps an existing rollup for a windowed date whose source events were pruned" do
      Fabricate(
        :browser_pageview_session_engagement_daily_rollup,
        date: Date.new(2026, 6, 10),
        sessions: 5,
      )
      Fabricate(:browser_pageview_event, created_at: Time.utc(2026, 6, 12, 9))

      described_class.aggregate(start_date:, end_date:)

      expect(described_class.where(date: Date.new(2026, 6, 10)).pick(:sessions)).to eq(5)
    end

    it "aggregates sessions on the range's boundary days but excludes those outside it" do
      freeze_time(Time.utc(2026, 7, 15, 12, 0, 0))
      Fabricate(:browser_pageview_event, created_at: Time.utc(2026, 6, 10, 9))
      Fabricate(:browser_pageview_event, created_at: Time.utc(2026, 6, 1, 0, 0))
      Fabricate(:browser_pageview_event, created_at: Time.utc(2026, 6, 30, 23, 0))
      Fabricate(:browser_pageview_event, created_at: Time.utc(2026, 5, 10, 9))
      Fabricate(:browser_pageview_event, created_at: Time.utc(2026, 7, 10, 9))

      described_class.aggregate(start_date:, end_date:)

      expect(described_class.pluck(:date)).to contain_exactly(
        Date.new(2026, 6, 1),
        Date.new(2026, 6, 10),
        Date.new(2026, 6, 30),
      )
    end

    it "excludes a session whose first pageview is before the range but continues inside it" do
      event = Fabricate(:browser_pageview_event, created_at: Time.utc(2026, 5, 31, 23, 30))
      Fabricate(
        :browser_pageview_event,
        session_id: event.session_id,
        created_at: Time.utc(2026, 6, 1, 0, 30),
      )

      described_class.aggregate(start_date:, end_date:)

      expect(described_class.count).to eq(0)
    end

    it "excludes sessions that started within the last 10 minutes" do
      Fabricate(:browser_pageview_event, created_at: Time.utc(2026, 6, 20, 11, 55))
      Fabricate(:browser_pageview_event, created_at: Time.utc(2026, 6, 20, 11, 45))

      described_class.aggregate(start_date:, end_date:)

      expect(described_class.all).to contain_exactly(have_attributes(sessions: 1))
    end

    it "does not bounce a session whose second pageview arrived within the last 10 minutes" do
      event = Fabricate(:browser_pageview_event, created_at: Time.utc(2026, 6, 20, 11, 30))
      Fabricate(
        :browser_pageview_event,
        session_id: event.session_id,
        created_at: Time.utc(2026, 6, 20, 11, 58),
      )

      described_class.aggregate(start_date:, end_date:)

      expect(described_class.all).to contain_exactly(have_attributes(sessions: 1, bounced: 0))
    end

    it "updates existing rows when re-aggregating with new sessions" do
      first_event = Fabricate(:browser_pageview_event, created_at: Time.utc(2026, 6, 10, 9))
      Fabricate(
        :browser_pageview_session_engagement,
        session_id: first_event.session_id,
        engaged_seconds: 5,
      )
      described_class.aggregate(start_date:, end_date:)

      second_event = Fabricate(:browser_pageview_event, created_at: Time.utc(2026, 6, 10, 9))
      Fabricate(
        :browser_pageview_session_engagement,
        session_id: second_event.session_id,
        engaged_seconds: 5,
      )
      described_class.aggregate(start_date:, end_date:)

      expect(described_class.all).to contain_exactly(
        have_attributes(sessions: 2, bounced: 2, engaged_seconds_total: 10),
      )
    end
  end
end
