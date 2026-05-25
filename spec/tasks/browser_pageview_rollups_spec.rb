# frozen_string_literal: true

RSpec.describe "tasks/browser_pageview_rollups" do
  describe "browser_pageview_rollups:backfill" do
    before { Discourse.stubs(:current_hostname).returns("forum.example.com") }

    it "backfills both country and referrer rollups for the given date range" do
      Fabricate(
        :browser_pageview_event,
        country_code: "US",
        normalized_referrer: "google.com",
        created_at: 5.days.ago,
      )

      start_date = 7.days.ago.to_date.to_s
      end_date = Date.current.to_s

      capture_stdout { invoke_rake_task("browser_pageview_rollups:backfill", start_date, end_date) }

      expect(BrowserPageviewCountryDailyRollup.where(country_code: "US").sum(:count)).to eq(1)
      expect(
        BrowserPageviewReferrerDailyRollup.where(normalized_referrer: "google.com").sum(:count),
      ).to eq(1)
    end

    it "defaults to the earliest event date when no start_date is provided" do
      Fabricate(:browser_pageview_event, country_code: "US", created_at: 60.days.ago)

      capture_stdout { invoke_rake_task("browser_pageview_rollups:backfill") }

      expect(BrowserPageviewCountryDailyRollup.where(country_code: "US").sum(:count)).to eq(1)
    end

    it "aggregates events that span a month boundary into their respective day rows" do
      previous_month = 1.month.ago.beginning_of_month + 5.days
      current_month = Time.current.beginning_of_month + 5.days
      Fabricate(:browser_pageview_event, country_code: "US", created_at: previous_month)
      Fabricate(:browser_pageview_event, country_code: "GB", created_at: current_month)

      start_date = (previous_month - 2.days).to_date.to_s
      end_date = (current_month + 2.days).to_date.to_s

      capture_stdout { invoke_rake_task("browser_pageview_rollups:backfill", start_date, end_date) }

      country_dates = BrowserPageviewCountryDailyRollup.pluck(:date)
      expect(country_dates).to contain_exactly(previous_month.to_date, current_month.to_date)
    end

    it "is idempotent — running twice does not double-count" do
      Fabricate(:browser_pageview_event, country_code: "US")

      start_date = 7.days.ago.to_date.to_s
      end_date = Date.current.to_s

      capture_stdout do
        invoke_rake_task("browser_pageview_rollups:backfill", start_date, end_date)
        Rake::Task["browser_pageview_rollups:backfill"].reenable
        invoke_rake_task("browser_pageview_rollups:backfill", start_date, end_date)
      end

      expect(BrowserPageviewCountryDailyRollup.where(country_code: "US").sum(:count)).to eq(1)
    end
  end
end
