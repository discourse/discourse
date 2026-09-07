# frozen_string_literal: true

RSpec.describe ApplicationRequest do
  before do
    ApplicationRequest.enable
    CachedCounting.reset
    CachedCounting.enable
  end

  after do
    ApplicationRequest.disable
    CachedCounting.disable
  end

  def inc(key)
    ApplicationRequest.increment!(key)
  end

  describe ".browser_pageviews" do
    it "preserves the first partial beacon day and switches both cohorts the following day" do
      today = Date.current
      history =
        described_class.create!(date: today - 2, req_type: :page_view_anon_browser, count: 4)
      described_class.create!(date: today - 2, req_type: :page_view_anon_browser_beacon, count: 0)
      first_day =
        described_class.create!(date: today - 1, req_type: :page_view_anon_browser, count: 1000)
      described_class.create!(date: today - 1, req_type: :page_view_anon_browser_beacon, count: 50)
      described_class.create!(
        date: today - 1,
        req_type: :page_view_logged_in_browser_beacon,
        count: 5,
      )
      beacon =
        described_class.create!(date: today, req_type: :page_view_anon_browser_beacon, count: 8)
      described_class.create!(date: today, req_type: :page_view_anon_browser, count: 3)
      described_class.create!(
        date: today,
        req_type: :page_view_anon_browser_mobile_beacon,
        count: 2,
      )

      expect(described_class.browser_pageviews).to contain_exactly(history, first_day, beacon)
    end

    it "includes the first beacon day when piggyback counters are absent or zero" do
      today = Date.current
      described_class.create!(date: today, req_type: :page_view_anon_browser, count: 0)
      beacon =
        described_class.create!(date: today, req_type: :page_view_anon_browser_beacon, count: 8)

      expect(described_class.browser_pageviews).to contain_exactly(beacon)
    end

    it "uses piggyback history when no beacons have been recorded" do
      history =
        described_class.create!(date: Date.current, req_type: :page_view_anon_browser, count: 4)

      expect(described_class.browser_pageviews).to contain_exactly(history)
    end
  end

  it "can log app requests" do
    freeze_time
    d1 = Time.now.utc.to_date

    4.times { inc("http_2xx") }

    inc("http_background")

    freeze_time 1.day.from_now
    d2 = Time.now.utc.to_date

    inc("page_view_crawler")
    inc("http_2xx")

    CachedCounting.flush

    expect(ApplicationRequest.find_by(date: d1, req_type: "http_2xx").count).to eq(4)
    expect(ApplicationRequest.find_by(date: d1, req_type: "http_background").count).to eq(1)

    expect(ApplicationRequest.find_by(date: d2, req_type: "page_view_crawler").count).to eq(1)
    expect(ApplicationRequest.find_by(date: d2, req_type: "http_2xx").count).to eq(1)
  end
end
