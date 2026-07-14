# frozen_string_literal: true

describe Reports::TopCountriesByBrowserPageviews do
  describe ".report_top_countries_by_browser_pageviews" do
    let(:start_date) { 7.days.ago.to_date }
    let(:end_date) { Date.today }

    let(:report) do
      BrowserPageviewCountryDailyRollup.aggregate(start_date: start_date, end_date: end_date)
      BrowserPageviewEvent.delete_all
      Report.find("top_countries_by_browser_pageviews", start_date: start_date, end_date: end_date)
    end

    it "ranks countries by event count and computes percent of total browser pageviews" do
      3.times { Fabricate(:browser_pageview_event, country_code: "US") }
      1.times { Fabricate(:browser_pageview_event, country_code: "GB") }

      data = report.data
      expect(data.map { |row| row[:country_code] }).to eq(%w[US GB])
      expect(data.first[:count]).to eq(3)
      expect(data.first[:percent]).to eq(75)
    end

    it "excludes NULL country_code from numerator but includes in denominator" do
      2.times { Fabricate(:browser_pageview_event, country_code: "US") }
      2.times { Fabricate(:browser_pageview_event, country_code: nil) }

      data = report.data
      expect(data.map { |row| row[:country_code] }).to eq(%w[US])
      expect(data.first[:percent]).to eq(50)
    end

    it "excludes MaxMind reserved country codes" do
      Reports::TopCountriesByBrowserPageviews::EXCLUDED_COUNTRY_CODES.each do |code|
        Fabricate(:browser_pageview_event, country_code: code)
      end
      Fabricate(:browser_pageview_event, country_code: "US")

      expect(report.data.map { |row| row[:country_code] }).to eq(%w[US])
    end

    it "counts only logged-in events in both numerator and denominator when login_required is true" do
      SiteSetting.login_required = true
      user = Fabricate(:user)
      Fabricate(:browser_pageview_event, country_code: "US", user_id: user.id)
      Fabricate(:browser_pageview_event, country_code: "US") # anonymous, ignored
      Fabricate(:browser_pageview_event, country_code: "GB", user_id: user.id)

      data = report.data
      expect(data.map { |row| row[:country_code] }).to contain_exactly("US", "GB")
      expect(data.first[:count]).to eq(1)
      expect(data.first[:percent]).to eq(50)
    end

    it "returns empty data when no events exist in range" do
      expect(report.data).to eq([])
    end

    it "treats the end_date day as fully inclusive via strict less-than on end_date + 1" do
      end_of_day = end_date.to_time + 23.hours + 59.minutes
      next_day = (end_date + 1.day).to_time
      Fabricate(:browser_pageview_event, country_code: "US", created_at: end_of_day)
      Fabricate(:browser_pageview_event, country_code: "US", created_at: next_day) # out of range

      expect(report.data.first[:count]).to eq(1)
    end

    it "caps results at MAX_ROWS when no explicit limit is given" do
      stub_const(Reports::TopCountriesByBrowserPageviews, "MAX_ROWS", 2) do
        %w[US GB DE].each { |code| Fabricate(:browser_pageview_event, country_code: code) }

        expect(report.data.size).to eq(2)
      end
    end
  end
end
