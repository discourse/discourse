# frozen_string_literal: true

RSpec.describe Reports::TopEntryUrls do
  let(:start_date) { "2026-05-01".to_date }
  let(:end_date) { "2026-05-07".to_date }

  def report
    Report.find("top_entry_urls", start_date:, end_date:)
  end

  def create_rollup(
    entry_url,
    count:,
    logged_in_count: 0,
    likely_crawler_count: 0,
    likely_crawler_logged_in_count: 0
  )
    BrowserPageviewEntryUrlDailyRollup.create!(
      date: start_date,
      entry_url:,
      count:,
      logged_in_count:,
      likely_crawler_count:,
      likely_crawler_logged_in_count:,
    )
  end

  it "describes entry URLs as report links" do
    expect(report.labels.first).to include(type: :link, properties: %i[entry_url entry_url])
  end

  it "excludes the full rebuild marker" do
    BrowserPageviewEntryUrlDailyRollup.mark_full_rebuild(date: start_date)

    expect(report.data).to be_empty
  end

  it "ranks entry URLs and calculates percentages from all qualifying pageviews" do
    create_rollup("/t/topic/1", count: 5)
    create_rollup("/categories", count: 3)
    create_rollup("/faq", count: 2)

    expect(report.data).to eq(
      [
        { entry_url: "/t/topic/1", count: 5, percent: 50 },
        { entry_url: "/categories", count: 3, percent: 30 },
        { entry_url: "/faq", count: 2, percent: 20 },
      ],
    )
  end

  it "uses logged-in and likely-crawler count dimensions consistently" do
    create_rollup(
      "/latest",
      count: 5,
      logged_in_count: 3,
      likely_crawler_count: 2,
      likely_crawler_logged_in_count: 1,
    )

    SiteSetting.login_required = true
    SiteSetting.improved_crawler_detection = true

    expect(report.data).to eq([{ entry_url: "/latest", count: 2, percent: 100 }])
  end

  it "limits displayed rows without truncating the percentage denominator" do
    stub_const(described_class, "MAX_ROWS", 2) do
      create_rollup("/a", count: 5)
      create_rollup("/b", count: 3)
      create_rollup("/c", count: 2)

      expect(report.data).to eq(
        [{ entry_url: "/a", count: 5, percent: 50 }, { entry_url: "/b", count: 3, percent: 30 }],
      )
    end
  end
end
