# frozen_string_literal: true

RSpec.describe BrowserPageviewSessionDailyRollup do
  before { freeze_time(Time.zone.local(2026, 5, 14, 12, 0, 0)) }

  let(:start_date) { Date.new(2026, 5, 1) }
  let(:end_date) { Date.new(2026, 5, 14) }

  describe ".aggregate" do
    it "groups events sharing a session_id into a single visit with a span-based duration" do
      first_pageview =
        Fabricate(:browser_pageview_event, created_at: Time.zone.local(2026, 5, 5, 10, 0, 0))
      Fabricate(
        :browser_pageview_event,
        session_id: first_pageview.session_id,
        created_at: Time.zone.local(2026, 5, 5, 10, 0, 10),
      )
      Fabricate(
        :browser_pageview_event,
        session_id: first_pageview.session_id,
        created_at: Time.zone.local(2026, 5, 5, 10, 0, 30),
      )

      described_class.aggregate(start_date: start_date, end_date: end_date)

      expect(
        described_class.order(:date, :logged_in).pluck(
          :date,
          :logged_in,
          :sessions_count,
          :bounced_count,
          :total_duration_seconds,
        ),
      ).to eq([[Date.new(2026, 5, 5), false, 1, 0, 30]])
    end

    it "counts a single-pageview visit with no engagement as a bounce of zero duration" do
      Fabricate(:browser_pageview_event, created_at: Time.zone.local(2026, 5, 5, 10, 0, 0))

      described_class.aggregate(start_date: start_date, end_date: end_date)

      expect(
        described_class.order(:date, :logged_in).pluck(
          :date,
          :logged_in,
          :sessions_count,
          :bounced_count,
          :total_duration_seconds,
        ),
      ).to eq([[Date.new(2026, 5, 5), false, 1, 1, 0]])
    end

    it "does not count a single-pageview visit as a bounce when the user stayed exactly 10s" do
      pageview =
        Fabricate(:browser_pageview_event, created_at: Time.zone.local(2026, 5, 5, 10, 0, 0))
      Fabricate(
        :browser_pageview_engagement,
        event: pageview,
        created_at: Time.zone.local(2026, 5, 5, 10, 0, 10),
      )

      described_class.aggregate(start_date: start_date, end_date: end_date)

      expect(
        described_class.order(:date, :logged_in).pluck(
          :date,
          :logged_in,
          :sessions_count,
          :bounced_count,
          :total_duration_seconds,
        ),
      ).to eq([[Date.new(2026, 5, 5), false, 1, 0, 10]])
    end

    it "counts a single-pageview visit that left under 10s as a bounce" do
      pageview =
        Fabricate(:browser_pageview_event, created_at: Time.zone.local(2026, 5, 5, 10, 0, 0))
      Fabricate(
        :browser_pageview_engagement,
        event: pageview,
        created_at: Time.zone.local(2026, 5, 5, 10, 0, 5),
      )

      described_class.aggregate(start_date: start_date, end_date: end_date)

      expect(
        described_class.order(:date, :logged_in).pluck(
          :date,
          :logged_in,
          :sessions_count,
          :bounced_count,
          :total_duration_seconds,
        ),
      ).to eq([[Date.new(2026, 5, 5), false, 1, 1, 5]])
    end

    it "adds only the final page's dwell to the visit duration" do
      first_pageview =
        Fabricate(:browser_pageview_event, created_at: Time.zone.local(2026, 5, 5, 10, 0, 0))
      last_pageview =
        Fabricate(
          :browser_pageview_event,
          session_id: first_pageview.session_id,
          created_at: Time.zone.local(2026, 5, 5, 10, 0, 20),
        )
      Fabricate(
        :browser_pageview_engagement,
        event: last_pageview,
        created_at: Time.zone.local(2026, 5, 5, 10, 0, 35),
      )
      # A later ping for an earlier pageview must not extend the visit — only
      # the final pageview's pings count; earlier pages' dwell is already the
      # timestamp gap to the next pageview.
      Fabricate(
        :browser_pageview_engagement,
        event: first_pageview,
        created_at: Time.zone.local(2026, 5, 5, 10, 0, 50),
      )

      described_class.aggregate(start_date: start_date, end_date: end_date)

      expect(
        described_class.order(:date, :logged_in).pluck(
          :date,
          :logged_in,
          :sessions_count,
          :bounced_count,
          :total_duration_seconds,
        ),
      ).to eq([[Date.new(2026, 5, 5), false, 1, 0, 35]])
    end

    it "uses the latest engagement ping when a page reports more than once" do
      pageview =
        Fabricate(:browser_pageview_event, created_at: Time.zone.local(2026, 5, 5, 10, 0, 0))
      Fabricate(
        :browser_pageview_engagement,
        event: pageview,
        created_at: Time.zone.local(2026, 5, 5, 10, 0, 5),
      )
      Fabricate(
        :browser_pageview_engagement,
        event: pageview,
        created_at: Time.zone.local(2026, 5, 5, 10, 0, 40),
      )

      described_class.aggregate(start_date: start_date, end_date: end_date)

      expect(
        described_class.order(:date, :logged_in).pluck(
          :date,
          :logged_in,
          :sessions_count,
          :bounced_count,
          :total_duration_seconds,
        ),
      ).to eq([[Date.new(2026, 5, 5), false, 1, 0, 40]])
    end

    it "ignores an exit ping that predates the visit's last pageview" do
      pageview =
        Fabricate(:browser_pageview_event, created_at: Time.zone.local(2026, 5, 5, 10, 0, 10))
      Fabricate(
        :browser_pageview_engagement,
        event: pageview,
        created_at: Time.zone.local(2026, 5, 5, 10, 0, 5),
      )

      described_class.aggregate(start_date: start_date, end_date: end_date)

      expect(
        described_class.order(:date, :logged_in).pluck(
          :date,
          :logged_in,
          :sessions_count,
          :bounced_count,
          :total_duration_seconds,
        ),
      ).to eq([[Date.new(2026, 5, 5), false, 1, 1, 0]])
    end

    it "caps each idle gap between pageviews at 30 minutes" do
      first_pageview =
        Fabricate(:browser_pageview_event, created_at: Time.zone.local(2026, 5, 5, 10, 0, 0))
      Fabricate(
        :browser_pageview_event,
        session_id: first_pageview.session_id,
        created_at: Time.zone.local(2026, 5, 5, 12, 0, 0),
      )
      Fabricate(
        :browser_pageview_event,
        session_id: first_pageview.session_id,
        created_at: Time.zone.local(2026, 5, 5, 14, 0, 0),
      )

      described_class.aggregate(start_date: start_date, end_date: end_date)

      expect(
        described_class.order(:date, :logged_in).pluck(
          :date,
          :logged_in,
          :sessions_count,
          :bounced_count,
          :total_duration_seconds,
        ),
      ).to eq([[Date.new(2026, 5, 5), false, 1, 0, 3600]])
    end

    it "counts a final-page ping received after midnight toward the prior day's visit" do
      pageview =
        Fabricate(:browser_pageview_event, created_at: Time.zone.local(2026, 5, 5, 23, 59, 50))
      Fabricate(
        :browser_pageview_engagement,
        event: pageview,
        created_at: Time.zone.local(2026, 5, 6, 0, 0, 5),
      )

      described_class.aggregate(start_date: start_date, end_date: end_date)

      expect(
        described_class.order(:date, :logged_in).pluck(
          :date,
          :logged_in,
          :sessions_count,
          :bounced_count,
          :total_duration_seconds,
        ),
      ).to eq([[Date.new(2026, 5, 5), false, 1, 0, 15]])
    end

    it "caps the final page's dwell at 30 minutes" do
      pageview =
        Fabricate(:browser_pageview_event, created_at: Time.zone.local(2026, 5, 5, 10, 0, 0))
      Fabricate(
        :browser_pageview_engagement,
        event: pageview,
        created_at: Time.zone.local(2026, 5, 5, 12, 0, 0),
      )

      described_class.aggregate(start_date: start_date, end_date: end_date)

      expect(
        described_class.order(:date, :logged_in).pluck(
          :date,
          :logged_in,
          :sessions_count,
          :bounced_count,
          :total_duration_seconds,
        ),
      ).to eq([[Date.new(2026, 5, 5), false, 1, 0, 1800]])
    end

    it "rolls up each day and audience separately across multiple days" do
      member = Fabricate(:user)

      # May 5: an anonymous bounce
      Fabricate(:browser_pageview_event, created_at: Time.zone.local(2026, 5, 5, 10, 0, 0))

      # May 6: an anonymous two-pageview visit (20s) and a logged-in visit with a 30s ping
      anon_first_pageview =
        Fabricate(:browser_pageview_event, created_at: Time.zone.local(2026, 5, 6, 10, 0, 0))
      Fabricate(
        :browser_pageview_event,
        session_id: anon_first_pageview.session_id,
        created_at: Time.zone.local(2026, 5, 6, 10, 0, 20),
      )

      member_pageview =
        Fabricate(
          :browser_pageview_event,
          user_id: member.id,
          created_at: Time.zone.local(2026, 5, 6, 11, 0, 0),
        )
      Fabricate(
        :browser_pageview_engagement,
        event: member_pageview,
        created_at: Time.zone.local(2026, 5, 6, 11, 0, 30),
      )

      described_class.aggregate(start_date: start_date, end_date: end_date)

      expect(
        described_class.order(:date, :logged_in).pluck(
          :date,
          :logged_in,
          :sessions_count,
          :bounced_count,
          :total_duration_seconds,
        ),
      ).to eq(
        [
          [Date.new(2026, 5, 5), false, 1, 1, 0],
          [Date.new(2026, 5, 6), false, 1, 0, 20],
          [Date.new(2026, 5, 6), true, 1, 0, 30],
        ],
      )
    end

    it "splits visits into separate rows for anonymous and logged-in audiences" do
      user = Fabricate(:user)
      Fabricate(:browser_pageview_event, created_at: Time.zone.local(2026, 5, 5, 10, 0, 0))
      Fabricate(
        :browser_pageview_event,
        user_id: user.id,
        created_at: Time.zone.local(2026, 5, 5, 10, 0, 0),
      )

      described_class.aggregate(start_date: start_date, end_date: end_date)

      expect(described_class.order(:logged_in).pluck(:logged_in, :sessions_count)).to eq(
        [[false, 1], [true, 1]],
      )
    end

    it "treats a visit where the user logged in partway through as logged-in" do
      user = Fabricate(:user)
      first_pageview =
        Fabricate(:browser_pageview_event, created_at: Time.zone.local(2026, 5, 5, 10, 0, 0))
      Fabricate(
        :browser_pageview_event,
        session_id: first_pageview.session_id,
        user_id: user.id,
        created_at: Time.zone.local(2026, 5, 5, 10, 0, 20),
      )

      described_class.aggregate(start_date: start_date, end_date: end_date)

      expect(described_class.pluck(:logged_in, :sessions_count)).to eq([[true, 1]])
    end

    it "attributes a visit spanning midnight to the day of its first pageview" do
      first_pageview =
        Fabricate(:browser_pageview_event, created_at: Time.zone.local(2026, 5, 5, 23, 50, 0))
      Fabricate(
        :browser_pageview_event,
        session_id: first_pageview.session_id,
        created_at: Time.zone.local(2026, 5, 6, 0, 10, 0),
      )

      described_class.aggregate(start_date: start_date, end_date: end_date)

      expect(
        described_class.order(:date, :logged_in).pluck(
          :date,
          :logged_in,
          :sessions_count,
          :bounced_count,
          :total_duration_seconds,
        ),
      ).to eq([[Date.new(2026, 5, 5), false, 1, 0, 1200]])
    end

    it "only aggregates visits whose first pageview falls within the requested range" do
      Fabricate(:browser_pageview_event, created_at: Time.zone.local(2026, 4, 20, 10, 0, 0))
      Fabricate(:browser_pageview_event, created_at: Time.zone.local(2026, 5, 5, 10, 0, 0))

      described_class.aggregate(start_date: start_date, end_date: end_date)

      expect(described_class.sum(:sessions_count)).to eq(1)
    end

    it "is idempotent — running twice produces the same totals" do
      first_pageview =
        Fabricate(:browser_pageview_event, created_at: Time.zone.local(2026, 5, 5, 10, 0, 0))
      Fabricate(
        :browser_pageview_event,
        session_id: first_pageview.session_id,
        created_at: Time.zone.local(2026, 5, 5, 10, 0, 20),
      )

      described_class.aggregate(start_date: start_date, end_date: end_date)
      described_class.aggregate(start_date: start_date, end_date: end_date)

      expect(
        described_class.order(:date, :logged_in).pluck(
          :date,
          :logged_in,
          :sessions_count,
          :bounced_count,
          :total_duration_seconds,
        ),
      ).to eq([[Date.new(2026, 5, 5), false, 1, 0, 20]])
    end
  end
end
