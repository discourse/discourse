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
    it "reads days with beacon traffic from beacons and the rest from piggyback counters" do
      today = Date.current
      history =
        described_class.create!(date: today - 2, req_type: :page_view_anon_browser, count: 4)
      described_class.create!(date: today - 2, req_type: :page_view_anon_browser_beacon, count: 0)
      anon_beacon =
        described_class.create!(
          date: today - 1,
          req_type: :page_view_anon_browser_beacon,
          count: 50,
        )
      logged_in_beacon =
        described_class.create!(
          date: today - 1,
          req_type: :page_view_logged_in_browser_beacon,
          count: 5,
        )
      described_class.create!(date: today - 1, req_type: :page_view_anon_browser, count: 1000)
      described_class.create!(
        date: today,
        req_type: :page_view_anon_browser_mobile_beacon,
        count: 2,
      )
      mobile_only_day =
        described_class.create!(date: today, req_type: :page_view_anon_browser, count: 3)

      expect(described_class.browser_pageviews).to contain_exactly(
        history,
        anon_beacon,
        logged_in_beacon,
        mobile_only_day,
      )
    end

    it "includes the first beacon day when piggyback counters are absent or zero" do
      today = Date.current
      described_class.create!(date: today, req_type: :page_view_anon_browser, count: 0)
      beacon =
        described_class.create!(date: today, req_type: :page_view_anon_browser_beacon, count: 8)

      expect(described_class.browser_pageviews).to contain_exactly(beacon)
    end

    it "keeps using piggyback counters on days a lone early beacon did not cover" do
      today = Date.current
      described_class.create!(date: today - 30, req_type: :page_view_anon_browser_beacon, count: 1)
      history = described_class.create!(date: today, req_type: :page_view_anon_browser, count: 100)

      expect(described_class.browser_pageviews.where(date: today)).to contain_exactly(history)
    end

    it "decides anonymous and logged in traffic separately on the same day" do
      today = Date.current
      logged_in =
        described_class.create!(date: today, req_type: :page_view_logged_in_browser, count: 40)
      described_class.create!(date: today, req_type: :page_view_anon_browser, count: 60)
      anon_beacon =
        described_class.create!(date: today, req_type: :page_view_anon_browser_beacon, count: 25)

      expect(described_class.browser_pageviews).to contain_exactly(logged_in, anon_beacon)
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
