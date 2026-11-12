# frozen_string_literal: true

RSpec.describe Reports::TopEntryUrls do
  let(:start_date) { "2026-05-01".to_date }
  let(:end_date) { "2026-05-07".to_date }

  it "makes entry URLs navigable" do
    expect(Report.find("top_entry_urls", start_date:, end_date:).labels.first).to include(
      type: :link,
      properties: %i[entry_url entry_url],
    )
  end

  it "ranks entry URLs and calculates percentages from all qualifying pageviews" do
    Fabricate(
      :browser_pageview_entry_url_daily_rollup,
      date: start_date,
      entry_url: "/t/topic/1",
      count: 5,
    )
    Fabricate(
      :browser_pageview_entry_url_daily_rollup,
      date: start_date,
      entry_url: "/categories",
      count: 3,
    )
    Fabricate(
      :browser_pageview_entry_url_daily_rollup,
      date: start_date,
      entry_url: "/faq",
      count: 2,
    )

    expect(Report.find("top_entry_urls", start_date:, end_date:).data).to eq(
      [
        { entry_url: "/t/topic/1", count: 5, percent: 50 },
        { entry_url: "/categories", count: 3, percent: 30 },
        { entry_url: "/faq", count: 2, percent: 20 },
      ],
    )
  end

  it "excludes anonymous and likely crawler pageviews when both filters apply" do
    Fabricate(
      :browser_pageview_entry_url_daily_rollup,
      date: start_date,
      entry_url: "/latest",
      count: 5,
      logged_in_count: 3,
      likely_crawler_count: 2,
      likely_crawler_logged_in_count: 1,
    )

    SiteSetting.login_required = true
    SiteSetting.improved_crawler_detection = true

    expect(Report.find("top_entry_urls", start_date:, end_date:).data).to eq(
      [{ entry_url: "/latest", count: 2, percent: 100 }],
    )
  end

  it "keeps percentages based on all rows when the display is limited" do
    stub_const(described_class, "MAX_ROWS", 2) do
      Fabricate(
        :browser_pageview_entry_url_daily_rollup,
        date: start_date,
        entry_url: "/a",
        count: 5,
      )
      Fabricate(
        :browser_pageview_entry_url_daily_rollup,
        date: start_date,
        entry_url: "/b",
        count: 3,
      )
      Fabricate(
        :browser_pageview_entry_url_daily_rollup,
        date: start_date,
        entry_url: "/c",
        count: 2,
      )

      expect(Report.find("top_entry_urls", start_date:, end_date:).data).to eq(
        [{ entry_url: "/a", count: 5, percent: 50 }, { entry_url: "/b", count: 3, percent: 30 }],
      )
    end
  end
end
