# frozen_string_literal: true

RSpec.describe AdminDashboardSearch do
  fab!(:user)

  before { freeze_time(Time.zone.local(2026, 5, 14, 12, 0, 0)) }

  describe ".build" do
    it "returns KPIs, trending terms, and content gaps for the selected dates, counting only logged-in members" do
      Fabricate.times(
        3,
        :clicked_search_log,
        term: "ruby",
        user: user,
        created_at: "2026-05-02 10:00",
      )
      Fabricate.times(3, :search_log, term: "ruby", user: user, created_at: "2026-05-02 11:00")

      Fabricate(
        :clicked_search_log,
        term: "markdown tables",
        user: user,
        created_at: "2026-05-03 10:00",
      )

      Fabricate.times(
        4,
        :search_log,
        term: "markdown tables",
        user: user,
        search_type: SearchLog.search_types[:full_page],
        created_at: "2026-05-03 11:00",
      )

      Fabricate.times(4, :search_log, term: "discobot", user: user, created_at: "2026-05-04 10:00")

      Fabricate.times(
        2,
        :clicked_search_log,
        term: "zeta",
        user: user,
        created_at: "2026-05-04 11:00",
      )
      Fabricate.times(2, :search_log, term: "zeta", user: user, created_at: "2026-05-04 12:00")

      Fabricate.times(
        5,
        :clicked_search_log,
        term: "ruby",
        user: user,
        created_at: "2026-04-26 10:00",
      )
      Fabricate.times(5, :search_log, term: "ghost", user: user, created_at: "2026-04-26 11:00")

      # Anonymous searches (likely crawlers) must be excluded from every metric and from the
      # prior-window deltas. If counted, "crawler-bait" would top trending, inflate the
      # no-result rate, and surface as a content gap; the anonymous "ruby" rows would change
      # its count and the percent change.
      Fabricate.times(30, :search_log, term: "crawler-bait", created_at: "2026-05-05 10:00")
      Fabricate.times(10, :search_log, term: "ruby", created_at: "2026-05-02 09:00")
      Fabricate.times(20, :search_log, term: "crawler-bait", created_at: "2026-04-26 09:00")

      expect(described_class.build(start_date: "2026-05-01", end_date: "2026-05-07")).to eq(
        logging_enabled: true,
        headline_state: "content_gaps",
        kpis: {
          total_searches: {
            value: 19,
            percent_change: 90,
          },
          no_result_rate: {
            value: 21,
            point_change: -29,
            exceeds_threshold: true,
          },
        },
        trending: [
          { term: "ruby", searches: 6 },
          { term: "markdown tables", searches: 5 },
          { term: "zeta", searches: 4 },
          { term: "discobot", searches: 4 },
        ],
        trending_period: "weekly",
        content_gaps: [
          { term: "markdown tables", searches: 5, status: "poor_match" },
          { term: "discobot", searches: 4, status: "no_match" },
        ],
      )
    end

    it "buckets terms by exact CTR boundaries" do
      Fabricate(:clicked_search_log, term: "tiny-ctr", user: user, created_at: "2026-05-02 10:00")
      Fabricate.times(
        100,
        :search_log,
        term: "tiny-ctr",
        user: user,
        created_at: "2026-05-02 11:00",
      )

      Fabricate.times(
        5,
        :clicked_search_log,
        term: "just-over",
        user: user,
        created_at: "2026-05-03 10:00",
      )
      Fabricate.times(
        19,
        :search_log,
        term: "just-over",
        user: user,
        created_at: "2026-05-03 11:00",
      )

      Fabricate(
        :clicked_search_log,
        term: "exact-twenty",
        user: user,
        created_at: "2026-05-04 10:00",
      )
      Fabricate.times(
        4,
        :search_log,
        term: "exact-twenty",
        user: user,
        created_at: "2026-05-04 11:00",
      )

      Fabricate.times(
        3,
        :search_log,
        term: "zero-clicks",
        user: user,
        created_at: "2026-05-05 10:00",
      )
      Fabricate.times(
        3,
        :search_log,
        term: "alpha-zero",
        user: user,
        created_at: "2026-05-05 11:00",
      )

      expect(described_class.build(start_date: "2026-05-01", end_date: "2026-05-07")).to eq(
        logging_enabled: true,
        headline_state: "healthy",
        kpis: {
          total_searches: {
            value: 136,
          },
          no_result_rate: {
            value: 4,
            exceeds_threshold: false,
          },
        },
        trending: [
          { term: "tiny-ctr", searches: 101 },
          { term: "just-over", searches: 24 },
          { term: "exact-twenty", searches: 5 },
          { term: "alpha-zero", searches: 3 },
          { term: "zero-clicks", searches: 3 },
        ],
        trending_period: "weekly",
        content_gaps: [
          { term: "tiny-ctr", searches: 101, status: "poor_match" },
          { term: "exact-twenty", searches: 5, status: "poor_match" },
          { term: "alpha-zero", searches: 3, status: "no_match" },
          { term: "zero-clicks", searches: 3, status: "no_match" },
        ],
      )
    end

    it "caps trending and content gaps at the top 10 terms" do
      (1..11).each do |index|
        Fabricate(
          :search_log,
          term: format("gap-%02d", index),
          user: user,
          created_at: "2026-05-02 10:00",
        )
      end

      expect(described_class.build(start_date: "2026-05-01", end_date: "2026-05-07")).to eq(
        logging_enabled: true,
        headline_state: "content_gaps",
        kpis: {
          total_searches: {
            value: 11,
          },
          no_result_rate: {
            value: 100,
            exceeds_threshold: true,
          },
        },
        trending: (1..10).map { |index| { term: format("gap-%02d", index), searches: 1 } },
        trending_period: "weekly",
        content_gaps:
          (1..10).map do |index|
            { term: format("gap-%02d", index), searches: 1, status: "no_match" }
          end,
      )
    end

    it "picks the headline state from the rate and volume signals" do
      Fabricate(:search_log, term: "ghost", user: user, created_at: "2026-05-02 10:00")
      Fabricate.times(
        11,
        :clicked_search_log,
        term: "ruby",
        user: user,
        created_at: "2026-05-02 11:00",
      )
      Fabricate.times(
        12,
        :clicked_search_log,
        term: "ruby",
        user: user,
        created_at: "2026-04-26 10:00",
      )

      Fabricate.times(
        4,
        :clicked_search_log,
        term: "ruby",
        user: user,
        created_at: "2026-04-02 10:00",
      )
      Fabricate.times(
        10,
        :clicked_search_log,
        term: "ruby",
        user: user,
        created_at: "2026-03-27 10:00",
      )

      Fabricate.times(
        12,
        :clicked_search_log,
        term: "ruby",
        user: user,
        created_at: "2026-03-02 10:00",
      )
      Fabricate.times(
        10,
        :clicked_search_log,
        term: "ruby",
        user: user,
        created_at: "2026-02-24 10:00",
      )

      expect(
        described_class.build(start_date: "2026-05-01", end_date: "2026-05-07")[:headline_state],
      ).to eq("rate_climbing")

      expect(
        described_class.build(start_date: "2026-04-01", end_date: "2026-04-07")[:headline_state],
      ).to eq("shrinking")

      expect(
        described_class.build(start_date: "2026-03-01", end_date: "2026-03-07")[:headline_state],
      ).to eq("healthy")
    end

    it "resolves overlapping headline states by priority" do
      Fabricate.times(3, :search_log, term: "ghost", user: user, created_at: "2026-02-02 10:00")
      Fabricate.times(
        7,
        :clicked_search_log,
        term: "ruby",
        user: user,
        created_at: "2026-02-02 11:00",
      )
      Fabricate.times(
        10,
        :clicked_search_log,
        term: "ruby",
        user: user,
        created_at: "2026-01-27 10:00",
      )

      Fabricate(:search_log, term: "ghost", user: user, created_at: "2026-01-02 10:00")
      Fabricate.times(
        9,
        :clicked_search_log,
        term: "ruby",
        user: user,
        created_at: "2026-01-02 11:00",
      )
      Fabricate.times(
        20,
        :clicked_search_log,
        term: "ruby",
        user: user,
        created_at: "2025-12-27 10:00",
      )

      expect(
        described_class.build(start_date: "2026-02-01", end_date: "2026-02-07")[:headline_state],
      ).to eq("content_gaps")

      expect(
        described_class.build(start_date: "2026-01-01", end_date: "2026-01-07")[:headline_state],
      ).to eq("rate_climbing")
    end

    it "omits deltas when the prior window has no searches" do
      Fabricate.times(
        2,
        :clicked_search_log,
        term: "ruby",
        user: user,
        created_at: "2026-05-02 10:00",
      )

      expect(described_class.build(start_date: "2026-05-01", end_date: "2026-05-07")[:kpis]).to eq(
        total_searches: {
          value: 2,
        },
        no_result_rate: {
          value: 0,
          exceeds_threshold: false,
        },
      )
    end

    it "omits deltas and rates when the current window has no searches" do
      Fabricate.times(2, :search_log, term: "ruby", user: user, created_at: "2026-04-26 10:00")

      expect(described_class.build(start_date: "2026-05-01", end_date: "2026-05-07")).to eq(
        logging_enabled: true,
        headline_state: "no_signal",
        kpis: {
          total_searches: {
            value: 0,
          },
          no_result_rate: {
            value: nil,
            exceeds_threshold: false,
          },
        },
        trending: [],
        trending_period: "weekly",
        content_gaps: [],
      )
    end

    it "omits deltas when nothing changed between the windows" do
      Fabricate.times(
        5,
        :clicked_search_log,
        term: "ruby",
        user: user,
        created_at: "2026-05-02 10:00",
      )
      Fabricate.times(
        5,
        :clicked_search_log,
        term: "ruby",
        user: user,
        created_at: "2026-04-26 10:00",
      )

      expect(described_class.build(start_date: "2026-05-01", end_date: "2026-05-07")[:kpis]).to eq(
        total_searches: {
          value: 5,
        },
        no_result_rate: {
          value: 0,
          exceeds_threshold: false,
        },
      )
    end

    it "reports the rate delta in percentage points, not relative change" do
      Fabricate(:search_log, term: "ghost", user: user, created_at: "2026-05-02 10:00")
      Fabricate.times(
        3,
        :clicked_search_log,
        term: "ruby",
        user: user,
        created_at: "2026-05-02 11:00",
      )

      Fabricate(:search_log, term: "ghost", user: user, created_at: "2026-04-26 10:00")
      Fabricate.times(
        9,
        :clicked_search_log,
        term: "ruby",
        user: user,
        created_at: "2026-04-26 11:00",
      )

      expect(described_class.build(start_date: "2026-05-01", end_date: "2026-05-07")[:kpis]).to eq(
        total_searches: {
          value: 4,
          percent_change: -60,
        },
        no_result_rate: {
          value: 25,
          point_change: 15,
          exceeds_threshold: true,
        },
      )
    end

    it "treats a rate of exactly 10% as within the threshold" do
      Fabricate(:search_log, term: "ghost", user: user, created_at: "2026-05-02 10:00")
      Fabricate.times(
        9,
        :clicked_search_log,
        term: "ruby",
        user: user,
        created_at: "2026-05-02 11:00",
      )

      expect(
        described_class.build(start_date: "2026-05-01", end_date: "2026-05-07")[:kpis][
          :no_result_rate
        ],
      ).to eq(value: 10, exceeds_threshold: false)
    end

    it "flags a rate just above 10% even when the display rounds to 10%" do
      Fabricate.times(5, :search_log, term: "ghost", user: user, created_at: "2026-05-02 10:00")
      Fabricate.times(
        44,
        :clicked_search_log,
        term: "ruby",
        user: user,
        created_at: "2026-05-02 11:00",
      )

      expect(
        described_class.build(start_date: "2026-05-01", end_date: "2026-05-07")[:kpis][
          :no_result_rate
        ],
      ).to eq(value: 10, exceeds_threshold: true)
    end

    it "maps the window length to the per-term report period" do
      {
        %w[2026-05-08 2026-05-14] => "weekly",
        %w[2026-05-07 2026-05-14] => "monthly",
        %w[2026-04-14 2026-05-14] => "monthly",
        %w[2026-04-13 2026-05-14] => "quarterly",
        %w[2026-02-12 2026-05-14] => "quarterly",
        %w[2026-02-11 2026-05-14] => "yearly",
        %w[2025-05-14 2026-05-14] => "yearly",
        %w[2025-05-13 2026-05-14] => "all",
      }.each do |(start_date, end_date), period|
        expect(
          described_class.build(start_date: start_date, end_date: end_date)[:trending_period],
        ).to eq(period)
      end
    end

    it "falls back to the default 30-day window for missing, malformed, or inverted dates" do
      Fabricate(:search_log, term: "inside-window", user: user, created_at: "2026-04-16 10:00")
      Fabricate(:search_log, term: "outside-window", user: user, created_at: "2026-04-13 10:00")

      [
        described_class.build(start_date: nil, end_date: nil),
        described_class.build(start_date: "not-a-date", end_date: "also-not-a-date"),
        described_class.build(start_date: "2026-05-10", end_date: "2026-05-01"),
      ].each do |response|
        expect(response[:kpis][:total_searches][:value]).to eq(1)
        expect(response[:trending]).to eq([{ term: "inside-window", searches: 1 }])
      end
    end

    it "includes searches at the window start boundary in every list" do
      Fabricate(:search_log, term: "boundary", user: user, created_at: "2026-05-01 00:00:00")

      response = described_class.build(start_date: "2026-05-01", end_date: "2026-05-07")

      expect(response[:kpis][:total_searches][:value]).to eq(1)
      expect(response[:trending]).to eq([{ term: "boundary", searches: 1 }])
      expect(response[:content_gaps]).to eq([{ term: "boundary", searches: 1, status: "no_match" }])
    end

    it "returns only the logging flag when search logging is disabled" do
      SiteSetting.log_search_queries = false

      Fabricate(:search_log, term: "ruby", user: user, created_at: "2026-05-02 10:00")

      expect(described_class.build(start_date: "2026-05-01", end_date: "2026-05-07")).to eq(
        logging_enabled: false,
      )
    end
  end
end
